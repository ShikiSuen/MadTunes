// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import AVFoundation

#if os(macOS)
import CoreAudio
#endif

// MARK: - AVEnginePlaybackBackend

/// Phase 176: Experimental playback backend driven by AVAudioEngine +
/// AVAudioPlayerNode. Decoding is performed by AVAudioFile (the same Apple
/// codecs AVPlayer uses); the engine graph performs sample-rate conversion
/// to the output device inside its render thread.
///
/// Known trade-offs vs. the AVPlayer backend:
/// - Repeat-one re-schedules the file from the render-completion callback,
///   which can leave a gap of a few milliseconds between iterations.
/// - Playback position is derived from render timestamps; it is less smooth
///   right after a seek until the first new render time arrives.
@MainActor
final class AVEnginePlaybackBackend: AudioPlaybackBackend {
  // MARK: Internal

  let kind: PlaybackEngineKind = .avAudioEngine

  var onReadyToPlay: (@MainActor (TimeInterval) -> Void)?
  var onPeriodicTime: (@MainActor (TimeInterval, TimeInterval) -> Void)?
  var onNaturalEnd: (@MainActor () -> Void)?
  var onFailure: (@MainActor () -> Void)?
  var onExternalPlayStateChange: (@MainActor (Bool) -> Void)?

  var repeatOneRequested = false

  var volume: Float = 1.0 {
    didSet { engine?.mainMixerNode.outputVolume = volume }
  }

  func play(url: URL, startAt: TimeInterval, autoPlay: Bool) {
    generation &+= 1
    teardownGraph()
    do {
      let file = try AVAudioFile(forReading: url)
      audioFile = file
      fileDuration = Double(file.length) / file.processingFormat.sampleRate
      try buildGraph(for: file)
      scheduleSegment(from: framePosition(for: startAt), autoPlay: autoPlay, generation: generation)
      installConfigChangeObserver()
      #if os(iOS)
      installInterruptionObserver()
      #endif
      startTimeTimer()
      onReadyToPlay?(fileDuration)
    } catch {
      print("[AVEngineBackend] ERROR: Failed to start playback: \(error)")
      teardownGraph()
      onFailure?()
    }
  }

  func pause() {
    playerNode?.pause()
    isNodePlaying = false
  }

  func resume() {
    guard let node = playerNode, let engine else { return }
    if !engine.isRunning {
      do {
        try engine.start()
      } catch {
        print("[AVEngineBackend] ERROR: Failed to restart engine on resume: \(error)")
        onFailure?()
        return
      }
    }
    node.play()
    isNodePlaying = true
  }

  func stop() {
    generation &+= 1
    teardownGraph()
  }

  func seek(to time: TimeInterval) {
    guard let node = playerNode, audioFile != nil else { return }
    generation &+= 1
    let wasPlaying = isNodePlaying
    let startFrame = framePosition(for: time)
    let expectedGeneration = generation
    // Phase 176 Task 3: AVAudioPlayerNode.stop() internally waits on a
    // Default-QoS worker thread; calling it on the main thread trips the
    // runtime priority-inversion diagnostic. Stop off-main, then hop back
    // to reschedule — stop must precede scheduleSegment because stop()
    // clears the node's pending events. All stops funnel through the serial
    // `stopQueue`, so a rapid second seek cannot have its freshly scheduled
    // segment wiped by the first seek's belated stop.
    let refs = SendableEngineRefs(engine: nil, node: node)
    stopQueue.async { [weak self] in
      refs.node?.stop()
      Task { @MainActor [weak self] in
        guard let self,
              self.generation == expectedGeneration,
              self.playerNode === refs.node
        else { return }
        self.scheduleSegment(from: startFrame, autoPlay: wasPlaying, generation: expectedGeneration)
      }
    }
  }

  #if os(macOS)
  func setOutputDevice(uid: String?) {
    outputDeviceUID = uid
    applyStoredOutputDevice()
  }
  #endif

  // MARK: Private

  private var engine: AVAudioEngine?
  private var playerNode: AVAudioPlayerNode?
  private var audioFile: AVAudioFile?
  private var fileDuration: TimeInterval = 0
  /// File frame at which the currently scheduled segment starts.
  private var segmentStartFrame: AVAudioFramePosition = 0
  private var generation: UInt = 0
  private var isNodePlaying = false
  private var timeTimer: Timer?
  private var configChangeObserver: (any NSObjectProtocol)?
  /// Phase 176 Task 3: Serial queue for blocking engine/node `stop()` calls,
  /// keeping them off the main thread and strictly ordered against each other.
  private let stopQueue = DispatchQueue(
    label: "MadTunes.AVEnginePlaybackBackend.stopQueue",
    qos: .userInitiated
  )

  #if os(iOS)
  private var interruptionObserver: (any NSObjectProtocol)?
  private var wasPlayingBeforeInterruption = false
  #endif

  #if os(macOS)
  private var outputDeviceUID: String?
  #endif

  // MARK: - Position Reporting

  /// Phase 176 Task 7: Last position sampled while the node was actually
  /// rendering. A configuration change kills render timestamps before the
  /// recovery code runs, so recovery must resume from this rather than from
  /// a fresh (already-fallen-back) estimate.
  private var lastRenderedFrame: AVAudioFramePosition = 0

  // MARK: - Graph Management

  /// Build and start a fresh engine + player node pair for `file`.
  private func buildGraph(for file: AVAudioFile) throws {
    let engine = AVAudioEngine()
    let node = AVAudioPlayerNode()
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
    engine.mainMixerNode.outputVolume = volume
    self.engine = engine
    playerNode = node
    #if os(macOS)
    applyStoredOutputDevice()
    #endif
    engine.prepare()
    try engine.start()
  }

  private func teardownGraph() {
    timeTimer?.invalidate()
    timeTimer = nil
    if let obs = configChangeObserver {
      NotificationCenter.default.removeObserver(obs)
      configChangeObserver = nil
    }
    #if os(iOS)
    if let obs = interruptionObserver {
      NotificationCenter.default.removeObserver(obs)
      interruptionObserver = nil
    }
    wasPlayingBeforeInterruption = false
    #endif
    // Phase 176 Task 3: node/engine stop() internally wait on a Default-QoS
    // worker thread; calling them on the main thread trips the runtime
    // priority-inversion diagnostic. The refs box keeps the old pair alive
    // until the detached stop completes; state is detached on-main right away.
    let refs = SendableEngineRefs(engine: engine, node: playerNode)
    stopQueue.async {
      refs.node?.stop()
      refs.engine?.stop()
    }
    playerNode = nil
    engine = nil
    audioFile = nil
    fileDuration = 0
    segmentStartFrame = 0
    lastRenderedFrame = 0
    isNodePlaying = false
  }

  // MARK: - Segment Scheduling

  private func framePosition(for seconds: TimeInterval) -> AVAudioFramePosition {
    guard let file = audioFile else { return 0 }
    let clamped = max(0, min(seconds, fileDuration))
    let frame = AVAudioFramePosition(clamped * file.processingFormat.sampleRate)
    return min(frame, file.length)
  }

  private func scheduleSegment(
    from startFrame: AVAudioFramePosition,
    autoPlay: Bool,
    generation expectedGeneration: UInt
  ) {
    guard let node = playerNode, let file = audioFile else { return }
    let remaining = file.length - startFrame
    guard remaining > 0 else {
      if repeatOneRequested {
        scheduleSegment(from: 0, autoPlay: autoPlay, generation: expectedGeneration)
      } else {
        isNodePlaying = false
        onNaturalEnd?()
      }
      return
    }
    segmentStartFrame = startFrame
    lastRenderedFrame = startFrame
    node.scheduleSegment(
      file,
      startingFrame: startFrame,
      frameCount: AVAudioFrameCount(remaining),
      at: nil,
      completionCallbackType: .dataPlayedBack
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, self.generation == expectedGeneration else { return }
        if self.repeatOneRequested {
          // The node is still playing here, so the re-scheduled segment starts
          // rendering right away; the MainActor hop may cost a few ms of gap.
          self.scheduleSegment(from: 0, autoPlay: true, generation: expectedGeneration)
        } else {
          self.isNodePlaying = false
          self.onNaturalEnd?()
        }
      }
    }
    if autoPlay {
      node.play()
      isNodePlaying = true
    }
  }

  private func currentFrameEstimate() -> AVAudioFramePosition {
    renderedFrameIfAvailable() ?? lastRenderedFrame
  }

  private func renderedFrameIfAvailable() -> AVAudioFramePosition? {
    guard let node = playerNode, let file = audioFile,
          let nodeTime = node.lastRenderTime,
          let playerTime = node.playerTime(forNodeTime: nodeTime) else { return nil }
    return min(segmentStartFrame + playerTime.sampleTime, file.length)
  }

  private func startTimeTimer() {
    timeTimer?.invalidate()
    // Phase 176 Task 6: deliberately NO generation guard here. seek() bumps
    // the generation, so a guarded timer would stop reporting after the
    // first seek and freeze the progress bar. Lifetime is already managed
    // by teardownGraph() invalidating the timer, and the audioFile guard
    // swallows any firing that was enqueued before a teardown.
    //
    // Phase 176 Task 8: schedule in .common runloop modes. A .default-mode
    // timer freezes while a context menu is open (event-tracking mode), so
    // position reporting went stale by the menu's open duration and an
    // engine switch issued from that menu resumed at a stale position
    // (verified: .default fires 0x during event-tracking, .common fires
    // normally). AVPlayer's periodic observer is GCD-driven and unaffected
    // by runloop modes, which made the asymmetry directional.
    let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self,
              let file = self.audioFile
        else { return }
        if let rendered = self.renderedFrameIfAvailable() {
          self.lastRenderedFrame = rendered
        }
        let current = Double(self.currentFrameEstimate()) / file.processingFormat.sampleRate
        self.onPeriodicTime?(current, self.fileDuration)
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    timeTimer = timer
  }

  // MARK: - Configuration Changes

  private func installConfigChangeObserver() {
    if let obs = configChangeObserver {
      NotificationCenter.default.removeObserver(obs)
    }
    let expectedGeneration = generation
    configChangeObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange,
      object: nil,
      queue: .main
    ) { [weak self] note in
      // Sending `note` into the MainActor task would trip Swift 6 region
      // isolation; box the engine reference instead (the box is Sendable).
      let refs = SendableEngineRefs(engine: note.object as? AVAudioEngine, node: nil)
      Task { @MainActor [weak self] in
        guard let self else { return }
        // Phase 176 Task 7: only react to our CURRENT engine — notifications
        // from a retired engine (e.g. its belated device application) are
        // stale by definition.
        guard let current = self.engine, refs.engine === current else { return }
        self.handleConfigurationChange(generation: expectedGeneration)
      }
    }
  }

  /// A device hot-plug / sample-rate change — or our own output-device
  /// application — interrupted the render thread.
  ///
  /// Phase 176 Task 7: recover with a same-engine restart. Verified on
  /// macOS 26: a device change kills the node's render timestamps, a bare
  /// `node.stop()` + reschedule + `play()` does NOT revive them, an engine
  /// stop/start DOES — and it fires no further notification, so recovery
  /// cannot loop. (The previous rebuild-per-notification design looped:
  /// every fresh engine needed a fresh device application, which fired the
  /// next notification.) Rebuild the graph only when the system actually
  /// detached our node or the restart failed.
  private func handleConfigurationChange(generation expectedGeneration: UInt) {
    guard generation == expectedGeneration, audioFile != nil else { return }
    let resumeFrame = currentFrameEstimate()
    let shouldResume = isNodePlaying
    // Phase 176 Task 3: stop/start off-main (priority-inversion discipline).
    let refs = SendableEngineRefs(engine: engine, node: playerNode)
    stopQueue.async { [weak self] in
      refs.node?.stop()
      refs.engine?.stop()
      var restarted = false
      if let engine = refs.engine {
        do {
          try engine.start()
          restarted = true
        } catch {
          restarted = false
        }
      }
      Task { @MainActor [weak self] in
        guard let self,
              self.generation == expectedGeneration,
              let file = self.audioFile
        else { return }
        let nodeDetached = self.playerNode?.engine == nil
        guard restarted, !nodeDetached else {
          do {
            try self.buildGraph(for: file)
            self.scheduleSegment(from: resumeFrame, autoPlay: shouldResume, generation: expectedGeneration)
          } catch {
            print("[AVEngineBackend] ERROR: Failed to rebuild after configuration change: \(error)")
            self.teardownGraph()
            self.onFailure?()
          }
          return
        }
        self.scheduleSegment(from: resumeFrame, autoPlay: shouldResume, generation: expectedGeneration)
      }
    }
  }

  // MARK: - Output Device Routing (macOS)

  #if os(macOS)
  /// Route the engine's output node to the stored device UID.
  /// CoreAudio calls run off-main to avoid priority-inversion warnings
  /// (same discipline as Phase 144).
  private func applyStoredOutputDevice() {
    guard let engine, let audioUnit = engine.outputNode.audioUnit else { return }
    let uid = outputDeviceUID
    Task.detached(priority: .userInitiated) {
      // Phase 176 Task 4: A nil/empty UID means "follow the system default".
      // That still requires an explicit write — the output unit does NOT
      // un-pin itself once a previous device override landed; skipping the
      // write leaves the old route stuck (silent at the expected device)
      // until the next full graph rebuild.
      let targetID: AudioDeviceID? = if let uid, !uid.isEmpty {
        Self.resolveDeviceID(uid: uid) ?? Self.resolveSystemDefaultOutputDeviceID()
      } else {
        Self.resolveSystemDefaultOutputDeviceID()
      }
      guard let deviceID = targetID else { return }
      var currentID = AudioDeviceID(0)
      var propSize = UInt32(MemoryLayout<AudioDeviceID>.size)
      AudioUnitGetProperty(
        audioUnit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &currentID,
        &propSize
      )
      // Only touch the unit when the route actually changes; setting the
      // property reconfigures the output and would retrigger a
      // configuration-change notification otherwise.
      guard currentID != deviceID else { return }
      var newID = deviceID
      AudioUnitSetProperty(
        audioUnit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &newID,
        UInt32(MemoryLayout<AudioDeviceID>.size)
      )
    }
  }

  private nonisolated static func resolveDeviceID(uid: String) -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    let cfUID = uid as CFString
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDeviceForUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = withUnsafePointer(to: cfUID) { cfUIDPtr in
      withUnsafeMutablePointer(to: &deviceID) { deviceIDPtr in
        var translation = AudioValueTranslation(
          mInputData: UnsafeMutableRawPointer(mutating: cfUIDPtr),
          mInputDataSize: UInt32(MemoryLayout<CFString>.size),
          mOutputData: UnsafeMutableRawPointer(deviceIDPtr),
          mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        var propSize = UInt32(MemoryLayout<AudioValueTranslation>.size)
        return AudioObjectGetPropertyData(
          AudioObjectID(kAudioObjectSystemObject),
          &address,
          0,
          nil,
          &propSize,
          &translation
        )
      }
    }
    guard status == noErr, deviceID != 0 else { return nil }
    return deviceID
  }

  /// Phase 176 Task 4: Resolve the current system default output device.
  private nonisolated static func resolveSystemDefaultOutputDeviceID() -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &deviceID
    )
    guard status == noErr, deviceID != 0 else { return nil }
    return deviceID
  }
  #endif

  // MARK: - Interruption Handling (iOS)

  #if os(iOS)
  private func installInterruptionObserver() {
    if let obs = interruptionObserver {
      NotificationCenter.default.removeObserver(obs)
    }
    let expectedGeneration = generation
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: nil,
      queue: .main
    ) { [weak self] note in
      // Parse the payload here; sending `note` into the MainActor task would
      // trip Swift 6 region isolation on the iOS SDK.
      let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
      let rawOptions = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
      Task { @MainActor [weak self] in
        guard let self, self.generation == expectedGeneration else { return }
        guard let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }
        switch type {
        case .began:
          self.wasPlayingBeforeInterruption = self.isNodePlaying
          if self.isNodePlaying {
            self.pause()
            self.onExternalPlayStateChange?(false)
          }
        case .ended:
          let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
          if options.contains(.shouldResume), self.wasPlayingBeforeInterruption {
            self.resume()
            self.onExternalPlayStateChange?(true)
          }
          self.wasPlayingBeforeInterruption = false
        @unknown default:
          break
        }
      }
    }
  }
  #endif
}

// MARK: - SendableEngineRefs

/// Phase 176 Task 3: @unchecked Sendable box for handing engine references to
/// a detached task. AVAudioEngine / AVAudioPlayerNode lifecycle calls are
/// internally locked and safe to invoke off-main; the box only satisfies
/// Swift 6 region isolation. Strong references keep the retired pair alive
/// until the detached `stop()` completes.
private struct SendableEngineRefs: @unchecked Sendable {
  let engine: AVAudioEngine?
  let node: AVAudioPlayerNode?
}
