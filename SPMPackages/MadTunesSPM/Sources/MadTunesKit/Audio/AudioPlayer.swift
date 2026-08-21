// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import AVFoundation
import Observation
import SwiftUI

#if os(macOS)
import CoreAudio
#endif

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import MediaPlayer

// Phase 106: Type alias for cross-platform image
#if canImport(UIKit)
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage
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

/// Playback coordinator. Manages a playback queue, Now Playing integration and
/// loop behavior; the actual audio rendering is delegated to an
/// `AudioPlaybackBackend` (AVPlayer by default, or the Phase 176 experimental
/// AVAudioEngine pipeline).
@Observable
@MainActor
public final class AudioPlayer {
  // MARK: Lifecycle

  // MARK: - Init

  nonisolated public init() {
    // Phase 104: Configure audio session for background playback on iOS.
    Task {
      #if os(iOS)
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
      } catch {
        print("[AudioPlayer] Failed to configure audio session: \(error)")
      }
      #endif
    }

    // actor work including library access must occur on main actor.
    Task { @MainActor in
      // take a snapshot so we know what IDs existed prior to any change.
      self.previousLibraryTrackIDs = Set(MadTunesViewModel.shared.library.tracks.map(\.id))
      await observeLibraryChanges()
    }
    // Different observation ops stay on different task.
    Task { @MainActor in
      await observeVolumeChanges()
    }
    // Phase 105: Setup remote command center.
    Task { @MainActor in
      self.setupRemoteCommandCenter()
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
  /// Phase 158: Structured playback error for UI display.
  public var lastPlaybackError: PlaybackError?

  /// Phase 176: The active playback pipeline (persisted; AVPlayer by default).
  /// Mutate through `setPlaybackEngineKind(_:)` so the backend is migrated.
  public var playbackEngineKind: PlaybackEngineKind {
    access(keyPath: \.playbackEngineKind)
    return _playbackEngineKind
  }

  // Phase 127: Audio output device routing (macOS only).
  #if os(macOS)
  /// Audio output device manager (initialized on first access).
  public var outputDeviceManager: AudioOutputDeviceManager {
    if let existing = _outputDeviceManager {
      return existing
    }
    let manager = AudioOutputDeviceManager()
    _outputDeviceManager = manager
    return manager
  }

  private var _outputDeviceManager: AudioOutputDeviceManager?

  /// Set the audio output device by UID. Pass `nil` for system default.
  public func setOutputDevice(uid: String?) {
    outputDeviceManager.selectedDeviceUID = uid
    backend?.setOutputDevice(uid: uid)
  }
  #endif

  /// Phase 176: Switch the playback pipeline. A loaded track is re-armed on the
  /// new backend at the current position, keeping the playing/paused state.
  public func setPlaybackEngineKind(_ newKind: PlaybackEngineKind) async {
    guard newKind != playbackEngineKind else { return }
    let trackToResume = currentTrack
    let resumeTime = currentTime
    let shouldAutoPlay = isPlaying
    withMutation(keyPath: \.playbackEngineKind) { _playbackEngineKind = newKind }
    guard trackToResume != nil else { return }
    teardownBackend()
    if let trackToResume {
      await play(trackToResume, startAt: resumeTime, autoPlay: shouldAutoPlay)
    }
  }

  /// 切換迴圈模式。新的取值會即時下發給當前播放後端。
  public func setLoopBehavior(_ newValue: PlayLoopBehavior) async {
    loopBehavior = newValue
    backend?.repeatOneRequested = (newValue == .repeatOne)
  }

  /// Replace the queue and start playing from the given index.
  public func setQueue(_ tracks: [Track], startingAt index: Int = 0) async {
    queue = tracks
    if tracks.indices.contains(index) {
      currentIndex = index
      await play(tracks[index])
    }
  }

  /// 在當前播放位置的下一首之前插入曲目，不中斷當前播放。
  /// Phase 39: 插播不應結束當前曲目，僅將曲目插入佇列中。
  public func insertNext(_ tracks: [Track]) async {
    guard !tracks.isEmpty else { return }
    let insertAt = min(currentIndex + 1, queue.count)
    queue.insert(contentsOf: tracks, at: insertAt)
    // 不修改 currentIndex，不中斷當前播放
  }

  /// Phase 178: Clear every queued track except the currently playing one
  /// (whether playing or paused). When no track is current, the queue is
  /// emptied entirely.
  public func clearQueueKeepingCurrentTrack() async {
    guard !queue.isEmpty else { return }
    guard let current = currentTrack else {
      queue.removeAll()
      currentIndex = 0
      return
    }
    let idsToRemove = Set(queue.map(\.id)).subtracting([current.id])
    await removeFromQueue(trackIDs: idsToRemove)
  }

  /// Move a track within the queue (for drag-to-reorder).
  public func moveQueueItem(from source: IndexSet, to destination: Int) async {
    let oldTrack = queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    queue.move(fromOffsets: source, toOffset: destination)
    // Re-sync currentIndex to follow the currently-playing track.
    if let oldTrack, let newIdx = queue.firstIndex(where: { $0.id == oldTrack.id }) {
      currentIndex = newIdx
    }
  }

  // MARK: - Playback Controls

  public func play(_ track: Track) async {
    await play(track, startAt: 0, autoPlay: true)
  }

  public func togglePlayPause() async {
    guard let backend else { return }
    if isPlaying {
      backend.pause()
    } else {
      backend.resume()
    }
    isPlaying.toggle()
    // Phase 105: Update Now Playing Info.
    updateNowPlayingInfo()
  }

  public func stop() async {
    teardownBackend()
    stopSecurityScopedAccess()
    currentTrack = nil
    currentTime = 0
    duration = 0
    isPlaying = false
    // Phase 105: Clear Now Playing Info.
    clearNowPlayingInfo()
  }

  /// Remove tracks from the current queue.
  ///
  /// If the currently playing track is removed, playback stops.
  /// Otherwise, the queue is updated preserving the current track position.
  public func removeFromQueue(trackIDs: Set<UUID>) async {
    guard !trackIDs.isEmpty else { return }

    // If the current track is being removed, stop playback entirely.
    if let current = currentTrack, trackIDs.contains(current.id) {
      await stop()
      queue.removeAll { trackIDs.contains($0.id) }
      currentIndex = 0
      return
    }

    // Otherwise, remove the tracks from the queue while keeping playback
    // position aligned with the currently playing track.
    let currentID = currentTrack?.id
    queue.removeAll { trackIDs.contains($0.id) }
    if let currentID,
       let idx = queue.firstIndex(where: { $0.id == currentID }) {
      currentIndex = idx
    } else {
      currentIndex = 0
    }
  }

  public func next() async {
    guard !queue.isEmpty else { return }
    switch loopBehavior {
    case .repeatOne:
      await seek(to: 0)
      backend?.resume()
    case .shuffle:
      currentIndex = Int.random(in: 0 ..< queue.count)
      await play(queue[currentIndex])
    case .sequential:
      let nextIndex = currentIndex + 1
      if nextIndex < queue.count {
        currentIndex = nextIndex
        await play(queue[nextIndex])
      } else {
        await stop()
      }
    }
  }

  public func previous() async {
    guard !queue.isEmpty else { return }
    if currentTime > 3 {
      await seek(to: 0)
    } else if currentIndex > 0 {
      currentIndex -= 1
      await play(queue[currentIndex])
    } else {
      await seek(to: 0)
    }
  }

  public func seek(to time: TimeInterval) async {
    guard backend != nil else { return }
    currentTime = time
    backend?.seek(to: time)
    // Phase 105: Update Now Playing Info.
    updateNowPlayingInfo()
  }

  // MARK: Private

  /// Phase 176: Persisted pipeline selection, bridged like Phase 145.
  @ObservationIgnored @AppStorage("MadTunes.playbackEngineKind")
  private var _playbackEngineKind: PlaybackEngineKind = .avPlayer

  /// Phase 176: The backend currently rendering audio (`nil` while stopped).
  private var backend: (any AudioPlaybackBackend)?

  private var activeSecurityScopedURL: URL?
  private var savedHALBufferFrameSize: UInt32?

  // MARK: - Queue Management

  private var previousLibraryTrackIDs: Set<UUID> = []

  /// Phase 108: Stored artwork data for the currently playing track.
  private var nowPlayingArtworkData: MPMediaItemArtwork?
  /// Phase 108: Album key for which `nowPlayingArtworkData` was loaded.
  private var nowPlayingArtworkKey: String?

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

  // MARK: - Backend Management (Phase 176)

  /// Returns the backend matching `playbackEngineKind`, creating and wiring
  /// one when necessary.
  private func ensureBackend() -> any AudioPlaybackBackend {
    if let backend, backend.kind == playbackEngineKind { return backend }
    backend?.stop()
    backend = nil

    let newBackend: any AudioPlaybackBackend = switch playbackEngineKind {
    case .avPlayer:
      AVPlayerPlaybackBackend()
    case .avAudioEngine:
      AVEnginePlaybackBackend()
    }

    newBackend.onReadyToPlay = { [weak self] loadedDuration in
      guard let self else { return }
      if loadedDuration.isFinite, loadedDuration > 0 {
        self.duration = loadedDuration
      }
      // Phase 105: Update Now Playing Info when track is ready to play.
      self.updateNowPlayingInfo()
    }
    newBackend.onPeriodicTime = { [weak self] current, reportedDuration in
      guard let self else { return }
      self.currentTime = current
      if reportedDuration.isFinite, reportedDuration > 0 {
        self.duration = reportedDuration
      }
      // Phase 105: Update Now Playing Info periodically.
      self.updateNowPlayingInfo()
    }
    newBackend.onNaturalEnd = { [weak self] in
      guard let self, self.isPlaying else { return }
      Task { @MainActor in
        await self.next()
      }
    }
    newBackend.onFailure = { [weak self] in
      guard let self else { return }
      self.lastPlaybackError = .avPlayerFailed(title: self.currentTrack?.title ?? "?")
      Self.playErrorBeep()
      self.isPlaying = false
    }
    newBackend.onExternalPlayStateChange = { [weak self] playing in
      guard let self else { return }
      self.isPlaying = playing
      self.updateNowPlayingInfo()
    }

    newBackend.volume = volume
    newBackend.repeatOneRequested = (loopBehavior == .repeatOne)
    #if os(macOS)
    newBackend.setOutputDevice(uid: outputDeviceManager.selectedDeviceUID)
    #endif

    backend = newBackend
    return newBackend
  }

  private func teardownBackend() {
    backend?.stop()
    backend = nil
    restoreHALBuffer()
  }

  @MainActor
  private func observeLibraryChanges() async {
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
          await self.handleLibraryTracksRemoval(removed)
        }
        // keep observing future changes
        await self.observeLibraryChanges()
      }
    }
  }

  @MainActor
  private func observeVolumeChanges() async {
    // Use the Observable macro helper to track changeID.
    // We re-register on each callback to keep the observation alive.
    withObservationTracking {
      _ = volume
    } onChange: { [weak self] in
      guard let this = self else { return }
      Task { @MainActor in
        if let backend = this.backend, backend.volume != this.volume {
          backend.volume = this.volume
        }
        // keep observing future changes
        await this.observeVolumeChanges()
      }
    }
  }

  // Called when the library announces that tracks have been deleted.  We
  // must purge any occurrences from our queue and stop playback if the
  // currently playing item is among them.
  private func handleLibraryTracksRemoval(_ ids: Set<UUID>) async {
    // remove from queue
    queue.removeAll { ids.contains($0.id) }
    if let curr = currentTrack, ids.contains(curr.id) {
      // track was playing -> stop entirely
      await stop()
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

  /// Enlarge the default output device's I/O buffer so the render pipeline has
  /// enough time per cycle, preventing HALC overload jitter.
  private func enlargeHALBufferIfNeeded() {
    #if os(macOS)
    guard savedHALBufferFrameSize == nil else { return } // already enlarged
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

  // MARK: - Track Loading

  private func play(_ track: Track, startAt: TimeInterval, autoPlay: Bool) async {
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
          lastPlaybackError = .securityScopeAccessDenied(title: track.title)
          Self.playErrorBeep()
          return
        }
      } else {
        print("[AudioPlayer] ERROR: File not readable and bookmark resolution failed for: \(playbackURL.path)")
        lastPlaybackError = .bookmarkResolutionFailed(title: track.title)
        Self.playErrorBeep()
        return
      }
    }

    // Stop any previous bookmark scope; adopt the new one.
    stopSecurityScopedAccess()
    activeSecurityScopedURL = bookmarkScopedURL

    currentTrack = track
    // Phase 108: Reset cached Now Playing artwork for new track.
    nowPlayingArtworkData = nil
    nowPlayingArtworkKey = nil

    if backend == nil { enlargeHALBufferIfNeeded() }
    let activeBackend = ensureBackend()
    currentTime = startAt
    duration = track.duration
    isPlaying = autoPlay
    activeBackend.play(url: playbackURL, startAt: startAt, autoPlay: autoPlay)
  }

  private func stopSecurityScopedAccess() {
    activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
    activeSecurityScopedURL = nil
  }

  // MARK: - Now Playing Info (Control Center / Lock Screen)

  /// Phase 105: Configure MPRemoteCommandCenter for Control Center / Lock Screen controls.
  @MainActor
  private func setupRemoteCommandCenter() {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Play command — only resume when paused (Phase 107 fix: was togglePlayPause).
    commandCenter.playCommand.addTarget { [weak self] _ in
      guard let self = self else { return .commandFailed }
      Task { @MainActor in
        if !self.isPlaying { await self.togglePlayPause() }
      }
      return .success
    }

    // Pause command — only pause when playing (Phase 107 fix: was togglePlayPause).
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      guard let self = self else { return .commandFailed }
      Task { @MainActor in
        if self.isPlaying { await self.togglePlayPause() }
      }
      return .success
    }

    // Toggle play/pause command
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      guard let self = self else { return .commandFailed }
      Task { @MainActor in
        await self.togglePlayPause()
      }
      return .success
    }

    // Next track command
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      guard let self = self else { return .commandFailed }
      Task { @MainActor in
        await self.next()
      }
      return .success
    }

    // Previous track command
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      guard let self = self else { return .commandFailed }
      Task { @MainActor in
        await self.previous()
      }
      return .success
    }

    // Change playback position (seek) command
    commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let self = self,
            let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
      Task { @MainActor in
        await self.seek(to: event.positionTime)
      }
      return .success
    }

    // Enable all commands by default
    commandCenter.playCommand.isEnabled = true
    commandCenter.pauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.changePlaybackPositionCommand.isEnabled = true
  }

  /// Phase 105: Update MPNowPlayingInfoCenter with current playback state.
  /// Phase 108: Artwork loaded asynchronously from SwiftData cache.
  @MainActor
  private func updateNowPlayingInfo() {
    var nowPlayingInfo: [String: Any] = [:]

    if let track = currentTrack {
      nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
      nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
      nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.albumTitle
      nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = track.duration

      // Phase 108: Use cached artwork if already loaded for current track.
      if let artwork = nowPlayingArtworkData {
        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
      } else {
        // Kick off async artwork load; will call updateNowPlayingInfo again.
        loadNowPlayingArtwork(for: track)
      }
    }

    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  /// Phase 108: Asynchronously load artwork from SwiftData for Now Playing info.
  private func loadNowPlayingArtwork(for track: Track) {
    let key = "\(track.albumTitle):::\(track.albumArtist)"
    guard key != nowPlayingArtworkKey else { return } // already loading / loaded
    Task {
      let result = await MadTunesViewModel.shared.library.loadArtwork(
        forAlbumKey: key,
        sampleTrackURL: track.fileURL,
        sampleTrackBookmark: track.bookmarkData
      )
      guard currentTrack?.id == track.id else { return } // track changed while loading
      if let data = result?.data {
        nowPlayingArtworkData = createMediaItemArtwork(from: data)
      } else {
        nowPlayingArtworkData = nil
      }
      nowPlayingArtworkKey = key
      updateNowPlayingInfo()
    }
  }

  // Phase 106: Create MPMediaItemArtwork from cached data.
  // Note: This method is nonisolated because MPMediaItemArtwork's handler
  // is called on a background queue by the system.
  nonisolated private func createMediaItemArtwork(from data: Data) -> MPMediaItemArtwork? {
    // Pre-create the image on the caller's context (MainActor)
    // Then capture it in the closure which runs on background queue
    let image: PlatformImage? = {
      guard let cgImage = CGImage.instantiate(data: data) else { return nil }
      #if canImport(UIKit)
      return UIImage(cgImage: cgImage)
      #elseif canImport(AppKit)
      return NSImage(cgImage: cgImage, size: NSSize(width: 600, height: 600))
      #else
      return nil
      #endif
    }()

    guard let platformImage = image else { return nil }
    let size = CGSize(width: 600, height: 600)

    return MPMediaItemArtwork(boundsSize: size) { _ in platformImage }
  }

  /// Phase 105: Clear Now Playing Info when playback stops.
  @MainActor
  private func clearNowPlayingInfo() {
    nowPlayingArtworkData = nil
    nowPlayingArtworkKey = nil
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }
}
