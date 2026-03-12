// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import AVFoundation
import Observation

#if os(macOS)
import CoreAudio
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - PlayLoopBehavior

public enum PlayLoopBehavior: Sendable {
  /// Play queue in order, stop when finished.
  case sequential
  /// Repeat the current single track.
  case repeatOne
  /// Shuffle the queue.
  case shuffle
}

// MARK: - AudioPlayer

/// Audio playback engine backed by AVPlayer. Manages a playback queue,
/// supports play/pause/seek/next/previous, and reports current time via observation.
@Observable
@MainActor
public final class AudioPlayer {
  // MARK: Lifecycle

  // MARK: - Init

  nonisolated public init() {
    // actor work including library access must occur on main actor.
    Task { @MainActor in
      // take a snapshot so we know what IDs existed prior to any change.
      self.previousLibraryTrackIDs = Set(MadTunesViewModel.shared.library.tracks.map(\.id))
      observeLibraryChanges()
    }
  }

  // MARK: Public

  // MARK: - Observable State

  public var currentTrack: Track?
  public var isPlaying: Bool = false
  public var currentTime: TimeInterval = 0
  public var duration: TimeInterval = 0
  public var volume: Float = 1.0
  public private(set) var queue: [Track] = []
  public private(set) var currentIndex: Int = 0
  public private(set) var loopBehavior: PlayLoopBehavior = .sequential

  /// 切換迴圈模式。若正在播放且 duration 已知，會立即安裝／拆除 boundary observer。
  public func setLoopBehavior(_ newValue: PlayLoopBehavior) {
    loopBehavior = newValue
    let currentDuration = CMTime(seconds: duration, preferredTimescale: 600)
    if newValue == .repeatOne,
       isPlaying,
       duration > 0,
       CMTimeGetSeconds(currentDuration).isFinite {
      setupRepeatOneLoopObserver(duration: currentDuration, generation: avPlayerGeneration)
    } else if newValue != .repeatOne {
      if let obs = loopBoundaryObserver {
        avPlayer?.removeTimeObserver(obs)
        loopBoundaryObserver = nil
      }
    }
  }

  /// Replace the queue and start playing from the given index.
  public func setQueue(_ tracks: [Track], startingAt index: Int = 0) {
    queue = tracks
    if tracks.indices.contains(index) {
      currentIndex = index
      play(tracks[index])
    }
  }

  /// 在當前播放位置的下一首之前插入曲目，不中斷當前播放。
  /// Phase 39: 插播不應結束當前曲目，僅將曲目插入佇列中。
  public func insertNext(_ tracks: [Track]) {
    guard !tracks.isEmpty else { return }
    let insertAt = min(currentIndex + 1, queue.count)
    queue.insert(contentsOf: tracks, at: insertAt)
    // 不修改 currentIndex，不中斷當前播放
  }

  /// Move a track within the queue (for drag-to-reorder).
  public func moveQueueItem(from source: IndexSet, to destination: Int) {
    let oldTrack = queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    queue.move(fromOffsets: source, toOffset: destination)
    // Re-sync currentIndex to follow the currently-playing track.
    if let oldTrack, let newIdx = queue.firstIndex(where: { $0.id == oldTrack.id }) {
      currentIndex = newIdx
    }
  }

  // MARK: - Playback Controls

  public func play(_ track: Track) {
    cleanupObservers()
    avPlayer?.pause()

    var playbackURL = track.fileURL
    var bookmarkScopedURL: URL?

    // If fileURL is not readable (e.g. after app relaunch), try bookmark.
    if !FileManager.default.isReadableFile(atPath: playbackURL.path) {
      if let bookmark = track.bookmarkData,
         let resolved = Self.resolveBookmark(bookmark) {
        if resolved.startAccessingSecurityScopedResource() {
          bookmarkScopedURL = resolved
          playbackURL = resolved
        } else {
          print("[AudioPlayer] ERROR: startAccessingSecurityScopedResource failed for: \(resolved.path)")
          Self.playErrorBeep()
          return
        }
      } else {
        print("[AudioPlayer] ERROR: File not readable and bookmark resolution failed for: \(playbackURL.path)")
        Self.playErrorBeep()
        return
      }
    }

    // Stop any previous bookmark scope; adopt the new one.
    stopSecurityScopedAccess()
    activeSecurityScopedURL = bookmarkScopedURL

    currentTrack = track
    playViaAVPlayer(url: playbackURL)
  }

  public func togglePlayPause() {
    guard let avPlayer else { return }
    if isPlaying {
      avPlayer.pause()
    } else {
      avPlayer.play()
    }
    isPlaying.toggle()
  }

  public func stop() {
    cleanupObservers()
    avPlayer?.pause()
    avPlayer = nil
    restoreHALBuffer()
    stopSecurityScopedAccess()
    currentTrack = nil
    currentTime = 0
    duration = 0
    isPlaying = false
  }

  public func next() {
    guard !queue.isEmpty else { return }
    switch loopBehavior {
    case .repeatOne:
      seek(to: 0)
      avPlayer?.play()
    case .shuffle:
      currentIndex = Int.random(in: 0 ..< queue.count)
      play(queue[currentIndex])
    case .sequential:
      let nextIndex = currentIndex + 1
      if nextIndex < queue.count {
        currentIndex = nextIndex
        play(queue[nextIndex])
      } else {
        stop()
      }
    }
  }

  public func previous() {
    guard !queue.isEmpty else { return }
    if currentTime > 3 {
      seek(to: 0)
    } else if currentIndex > 0 {
      currentIndex -= 1
      play(queue[currentIndex])
    } else {
      seek(to: 0)
    }
  }

  public func seek(to time: TimeInterval) {
    guard let avPlayer else { return }
    let cmTime = CMTime(seconds: time, preferredTimescale: 600)
    currentTime = time
    avPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
  }

  /// Update volume and sync to the underlying player.
  public func setVolume(_ newVolume: Float) {
    volume = newVolume
    avPlayer?.volume = newVolume
  }

  // MARK: Private

  private var avPlayer: AVPlayer?
  private var avPlayerEndObserver: Any?
  private var avPlayerGeneration: UInt = 0
  private var timeObserver: Any?
  private var loopBoundaryObserver: Any?
  private var itemStatusObservation: NSKeyValueObservation?
  private var activeSecurityScopedURL: URL?
  private var savedHALBufferFrameSize: UInt32?

  // MARK: - Queue Management

  private var previousLibraryTrackIDs: Set<UUID> = []

  // MARK: - Utilities

  private nonisolated static func resolveBookmark(_ data: Data) -> URL? {
    var stale = false
    #if os(macOS) || targetEnvironment(macCatalyst)
    return try? URL(
      resolvingBookmarkData: data,
      options: .withSecurityScope,
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    )
    #else
    return try? URL(
      resolvingBookmarkData: data,
      options: [],
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    )
    #endif
  }

  private nonisolated static func playErrorBeep() {
    #if os(macOS)
    NSSound.beep()
    #endif
  }

  @MainActor
  private func observeLibraryChanges() {
    // Use the Observable macro helper to track changeID.
    // We re-register on each callback to keep the observation alive.
    withObservationTracking {
      _ = MadTunesViewModel.shared.library.changeID
    } onChange: { [weak self] in
      guard let self = self else { return }
      Task { @MainActor in
        let library = MadTunesViewModel.shared.library
        let currentIDs = Set(library.tracks.map(\.id))
        let removed = self.previousLibraryTrackIDs.subtracting(currentIDs)
        self.previousLibraryTrackIDs = currentIDs
        if !removed.isEmpty {
          self.handleLibraryTracksRemoval(removed)
        }
        // keep observing future changes
        self.observeLibraryChanges()
      }
    }
  }

  // Called when the library announces that tracks have been deleted.  We
  // must purge any occurrences from our queue and stop playback if the
  // currently playing item is among them.
  private func handleLibraryTracksRemoval(_ ids: Set<UUID>) {
    // remove from queue
    queue.removeAll { ids.contains($0.id) }
    if let curr = currentTrack, ids.contains(curr.id) {
      // track was playing -> stop entirely
      stop()
    } else if let curr = currentTrack, let newIdx = queue.firstIndex(where: { $0.id == curr.id }) {
      currentIndex = newIdx
    } else {
      // queue no longer contains current track (could have been removed indirectly)
      if !queue.isEmpty {
        // pick first remaining track as a fallback? but we expect stop() earlier
      } else {
        currentIndex = 0
      }
    }
  }

  // MARK: - HAL Buffer Management

  /// Enlarge the default output device's I/O buffer so AVPlayer's high-quality
  /// SRC has enough time per cycle, preventing HALC overload jitter.
  private func enlargeHALBufferIfNeeded() {
    #if os(macOS)
    let desiredFrames: UInt32 = 1024

    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
    ) == noErr else { return }

    var currentFrames: UInt32 = 0
    var propSize = UInt32(MemoryLayout<UInt32>.size)
    address.mSelector = kAudioDevicePropertyBufferFrameSize
    address.mScope = kAudioDevicePropertyScopeOutput
    guard AudioObjectGetPropertyData(
      deviceID, &address, 0, nil, &propSize, &currentFrames
    ) == noErr else { return }

    guard currentFrames < desiredFrames else { return }
    savedHALBufferFrameSize = currentFrames

    var newFrames = desiredFrames
    AudioObjectSetPropertyData(
      deviceID, &address, 0, nil,
      UInt32(MemoryLayout<UInt32>.size), &newFrames
    )
    #endif
  }

  /// Restore the HAL buffer frame size saved by `enlargeHALBufferIfNeeded`.
  private func restoreHALBuffer() {
    #if os(macOS)
    guard let saved = savedHALBufferFrameSize else { return }
    savedHALBufferFrameSize = nil

    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
    ) == noErr else { return }

    var restoreFrames = saved
    address.mSelector = kAudioDevicePropertyBufferFrameSize
    address.mScope = kAudioDevicePropertyScopeOutput
    AudioObjectSetPropertyData(
      deviceID, &address, 0, nil,
      UInt32(MemoryLayout<UInt32>.size), &restoreFrames
    )
    #endif
  }

  // MARK: - AVPlayer Playback

  private func playViaAVPlayer(url: URL) {
    enlargeHALBufferIfNeeded()
    let item = AVPlayerItem(url: url)

    // Replace directly — do NOT nil-out first, which causes a pipeline
    // teardown race (FigFilePlayer err=-12864).
    if avPlayer == nil {
      avPlayer = AVPlayer(playerItem: item)
      avPlayer?.volume = volume
    } else {
      avPlayer?.replaceCurrentItem(with: item)
    }

    duration = currentTrack?.duration ?? 0
    isPlaying = true

    avPlayerGeneration &+= 1
    let expectedGeneration = avPlayerGeneration

    // KVO: wait for the new item to be ready before playing.
    itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
      Task { @MainActor [weak self] in
        guard let self, self.avPlayerGeneration == expectedGeneration else { return }
        self.itemStatusObservation = nil
        switch observedItem.status {
        case .readyToPlay:
          self.avPlayer?.play()
          let dur = CMTimeGetSeconds(observedItem.duration)
          if dur.isFinite, dur > 0 {
            self.duration = dur
            if self.loopBehavior == .repeatOne {
              self.setupRepeatOneLoopObserver(
                duration: observedItem.duration,
                generation: expectedGeneration
              )
            }
          }
        case .failed:
          print("[AudioPlayer] itemStatusObservation AVPlayerGeneration Status Failure.")
          Self.playErrorBeep()
          self.isPlaying = false
        default:
          break
        }
      }
    }

    setupTimeObserver(generation: expectedGeneration)
    setupEndObserver(for: item, generation: expectedGeneration)
  }

  // MARK: - Observation Setup

  private func setupTimeObserver(generation: UInt) {
    let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
    timeObserver = avPlayer?.addPeriodicTimeObserver(
      forInterval: interval, queue: .main
    ) { [weak self] time in
      Task { @MainActor in
        guard let self, self.avPlayerGeneration == generation else { return }
        self.currentTime = CMTimeGetSeconds(time)
        if let dur = self.avPlayer?.currentItem?.duration {
          let secs = CMTimeGetSeconds(dur)
          if secs.isFinite, secs > 0 { self.duration = secs }
        }
      }
    }
  }

  private func setupEndObserver(for item: AVPlayerItem, generation: UInt) {
    if let oldObserver = avPlayerEndObserver {
      NotificationCenter.default.removeObserver(oldObserver)
    }
    // For .repeatOne the boundary observer handles looping;
    // this notification fires only if seek latency causes us to miss the boundary
    // (unlikely for local files), so next() still handles it correctly.
    avPlayerEndObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self,
              self.isPlaying,
              self.avPlayerGeneration == generation
        else { return }
        self.next()
      }
    }
  }

  /// Sets up a boundary-time observer that seeks to the beginning ~0.17 s before
  /// the item's natural end, keeping the AVPlayer pipeline active and achieving
  /// a near-gapless loop without AVPlayerLooper's decoder-teardown overhead.
  private func setupRepeatOneLoopObserver(duration: CMTime, generation: UInt) {
    if let obs = loopBoundaryObserver {
      avPlayer?.removeTimeObserver(obs)
      loopBoundaryObserver = nil
    }
    // 0.17 s head-start gives the decoder enough time to re-prime from the
    // beginning before the last audio buffer drains — enough even for AAC.
    let offset = CMTime(value: 17, timescale: 100)
    let loopPoint = CMTimeSubtract(duration, offset)
    guard CMTimeGetSeconds(loopPoint) > 0 else { return }

    loopBoundaryObserver = avPlayer?.addBoundaryTimeObserver(
      forTimes: [NSValue(time: loopPoint)],
      queue: .main
    ) { [weak self] in
      Task { @MainActor [weak self] in
        guard let self,
              self.loopBehavior == .repeatOne,
              self.avPlayerGeneration == generation
        else { return }
        // Player is still in the "playing" state here — seek repositions
        // it without tearing down the pipeline, so it auto-resumes.
        self.avPlayer?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
      }
    }
  }

  private func cleanupObservers() {
    itemStatusObservation?.invalidate()
    itemStatusObservation = nil
    if let obs = timeObserver {
      avPlayer?.removeTimeObserver(obs)
      timeObserver = nil
    }
    if let obs = loopBoundaryObserver {
      avPlayer?.removeTimeObserver(obs)
      loopBoundaryObserver = nil
    }
    if let obs = avPlayerEndObserver {
      NotificationCenter.default.removeObserver(obs)
      avPlayerEndObserver = nil
    }
    restoreHALBuffer()
  }

  private func stopSecurityScopedAccess() {
    activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
    activeSecurityScopedURL = nil
  }
}
