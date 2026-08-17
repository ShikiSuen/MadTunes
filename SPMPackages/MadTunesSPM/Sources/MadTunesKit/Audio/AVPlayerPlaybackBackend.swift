// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import AVFoundation

// MARK: - AVPlayerPlaybackBackend

/// Phase 176: The long-standing default backend, extracted from `AudioPlayer`
/// verbatim: AVPlayer + CoreAudio, with KVO readiness, periodic time
/// observation, near-gapless repeat-one via a boundary observer, and macOS
/// output-device routing via `AVPlayer.audioOutputDeviceUniqueID`.
@MainActor
final class AVPlayerPlaybackBackend: AudioPlaybackBackend {
  // MARK: Internal

  let kind: PlaybackEngineKind = .avPlayer

  var onReadyToPlay: (@MainActor (TimeInterval) -> Void)?
  var onPeriodicTime: (@MainActor (TimeInterval, TimeInterval) -> Void)?
  var onNaturalEnd: (@MainActor () -> Void)?
  var onFailure: (@MainActor () -> Void)?
  /// AVPlayer handles system interruptions by itself; never fired here.
  var onExternalPlayStateChange: (@MainActor (Bool) -> Void)?

  var volume: Float = 1.0 {
    didSet { avPlayer?.volume = volume }
  }

  var repeatOneRequested: Bool = false {
    didSet {
      guard oldValue != repeatOneRequested else { return }
      if repeatOneRequested, startedPlayback, itemDuration > 0 {
        let cmDuration = CMTime(seconds: itemDuration, preferredTimescale: 600)
        guard CMTimeGetSeconds(cmDuration).isFinite else { return }
        setupRepeatOneLoopObserver(duration: cmDuration, generation: generation)
      } else if !repeatOneRequested {
        removeLoopBoundaryObserver()
      }
    }
  }

  func play(url: URL, startAt: TimeInterval, autoPlay: Bool) {
    cleanupObservers()
    avPlayer?.pause()
    startedPlayback = false
    itemDuration = 0
    pendingStartAt = startAt
    pendingAutoPlay = autoPlay

    let item = AVPlayerItem(url: url)
    // Phase 127 investigation: no public API exists for controlling AVPlayer SRC quality.
    // `AVMutableAudioMixInputParameters.audioProcessingSettings` +
    // `AVSampleRateConverterAlgorithmKey` / `AVSampleRateConverterAlgorithm_Mastering`
    // were removed from the macOS SDK (not present in macOS 26 SDK).
    // SRC is handled transparently by coreaudiod; apps cannot influence its quality tier.
    //
    // DO NOT set `item.audioTimePitchAlgorithm = .spectral` here.
    // `audioTimePitchAlgorithm` controls the time-stretch algorithm, which only engages
    // when AVPlayer.rate ≠ 1.0 (scaled edits / varispeed). At rate == 1.0, AVFoundation
    // bypasses the pitch/time-stretch pipeline entirely, but `.spectral` still inserts
    // an extra DSP stage that causes audible quality degradation — instruments lose
    // transient "breath" at higher volumes (verified by A/B listening test, Phase 127).
    // The macOS 12+ default `.timeDomain` must be left in place.

    if avPlayer == nil {
      // Replace directly — do NOT nil-out first, which causes a pipeline
      // teardown race (FigFilePlayer err=-12864).
      avPlayer = AVPlayer(playerItem: item)
      avPlayer?.volume = volume
      // Phase 127: Apply selected audio output device.
      #if os(macOS)
      avPlayer?.audioOutputDeviceUniqueID = outputDeviceUID
      #endif
    } else {
      avPlayer?.replaceCurrentItem(with: item)
    }

    generation &+= 1
    let expectedGeneration = generation

    // KVO: wait for the new item to be ready before playing.
    itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
      Task { @MainActor [weak self] in
        guard let self, self.generation == expectedGeneration else { return }
        self.itemStatusObservation = nil
        switch observedItem.status {
        case .readyToPlay:
          let dur = CMTimeGetSeconds(observedItem.duration)
          if dur.isFinite, dur > 0 {
            self.itemDuration = dur
            if self.repeatOneRequested {
              self.setupRepeatOneLoopObserver(
                duration: observedItem.duration,
                generation: expectedGeneration
              )
            }
          }
          if self.pendingStartAt > 0 {
            await self.avPlayer?.seek(
              to: CMTime(seconds: self.pendingStartAt, preferredTimescale: 600),
              toleranceBefore: .zero,
              toleranceAfter: .zero
            )
          }
          self.pendingStartAt = 0
          if self.pendingAutoPlay {
            self.avPlayer?.play()
            self.startedPlayback = true
          }
          self.onReadyToPlay?(dur.isFinite && dur > 0 ? dur : 0)
        case .failed:
          print("[AudioPlayer] itemStatusObservation AVPlayerGeneration Status Failure.")
          self.onFailure?()
        default:
          break
        }
      }
    }

    setupTimeObserver(generation: expectedGeneration)
    setupEndObserver(for: item, generation: expectedGeneration)
  }

  func pause() {
    avPlayer?.pause()
    startedPlayback = false
  }

  func resume() {
    guard avPlayer != nil else { return }
    avPlayer?.play()
    startedPlayback = true
  }

  func stop() {
    cleanupObservers()
    avPlayer?.pause()
    avPlayer = nil
    startedPlayback = false
    itemDuration = 0
  }

  func seek(to time: TimeInterval) {
    guard let avPlayer else { return }
    let cmTime = CMTime(seconds: time, preferredTimescale: 600)
    Task {
      await avPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
  }

  #if os(macOS)
  func setOutputDevice(uid: String?) {
    outputDeviceUID = uid
    avPlayer?.audioOutputDeviceUniqueID = uid
  }
  #endif

  // MARK: Private

  private var avPlayer: AVPlayer?
  private var endObserver: Any?
  private var generation: UInt = 0
  private var timeObserver: Any?
  private var loopBoundaryObserver: Any?
  private var itemStatusObservation: NSKeyValueObservation?
  private var startedPlayback = false
  private var itemDuration: TimeInterval = 0
  private var pendingStartAt: TimeInterval = 0
  private var pendingAutoPlay = true

  #if os(macOS)
  private var outputDeviceUID: String?
  #endif

  // MARK: - Observation Setup

  private func setupTimeObserver(generation: UInt) {
    let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
    timeObserver = avPlayer?.addPeriodicTimeObserver(
      forInterval: interval, queue: .main
    ) { [weak self] time in
      Task { @MainActor in
        guard let self, self.generation == generation else { return }
        let current = CMTimeGetSeconds(time)
        if let itemDur = self.avPlayer?.currentItem?.duration {
          let secs = CMTimeGetSeconds(itemDur)
          if secs.isFinite, secs > 0 { self.itemDuration = secs }
        }
        self.onPeriodicTime?(current, self.itemDuration)
      }
    }
  }

  private func setupEndObserver(for item: AVPlayerItem, generation: UInt) {
    if let oldObserver = endObserver {
      NotificationCenter.default.removeObserver(oldObserver)
    }
    // For .repeatOne the boundary observer handles looping;
    // this notification fires only if seek latency causes us to miss the boundary
    // (unlikely for local files), in which case we restart the item manually.
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, self.generation == generation else { return }
        if self.repeatOneRequested {
          self.avPlayer?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
          self.avPlayer?.play()
          self.startedPlayback = true
        } else {
          self.onNaturalEnd?()
        }
      }
    }
  }

  /// Sets up a boundary-time observer that seeks to the beginning ~0.17 s before
  /// the item's natural end, keeping the AVPlayer pipeline active and achieving
  /// a near-gapless loop without AVPlayerLooper's decoder-teardown overhead.
  private func setupRepeatOneLoopObserver(duration: CMTime, generation: UInt) {
    removeLoopBoundaryObserver()
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
              self.repeatOneRequested,
              self.generation == generation
        else { return }
        // Player is still in the "playing" state here — seek repositions
        // it without tearing down the pipeline, so it auto-resumes.
        self.avPlayer?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
      }
    }
  }

  private func removeLoopBoundaryObserver() {
    if let obs = loopBoundaryObserver {
      avPlayer?.removeTimeObserver(obs)
      loopBoundaryObserver = nil
    }
  }

  private func cleanupObservers() {
    itemStatusObservation?.invalidate()
    itemStatusObservation = nil
    if let obs = timeObserver {
      avPlayer?.removeTimeObserver(obs)
      timeObserver = nil
    }
    removeLoopBoundaryObserver()
    if let obs = endObserver {
      NotificationCenter.default.removeObserver(obs)
      endObserver = nil
    }
  }
}
