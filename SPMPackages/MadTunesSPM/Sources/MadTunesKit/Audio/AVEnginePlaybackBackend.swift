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

  // MARK: - Position Reporting

  private func currentFrameEstimate() -> AVAudioFramePosition {
    guard let node = playerNode, let file = audioFile else { return 0 }
    guard let nodeTime = node.lastRenderTime,
          let playerTime = node.playerTime(forNodeTime: nodeTime) else { return segmentStartFrame }
    return min(segmentStartFrame + playerTime.sampleTime, file.length)
  }

  private func startTimeTimer() {
    timeTimer?.invalidate()
    let expectedGeneration = generation
    timeTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self,
              self.generation == expectedGeneration,
              let file = self.audioFile
        else { return }
        let current = Double(self.currentFrameEstimate()) / file.processingFormat.sampleRate
        self.onPeriodicTime?(current, self.fileDuration)
      }
    }
  }

  // MARK: - Configuration Changes

  private func installConfigChangeObserver() {
    if let obs = configChangeObserver {
      NotificationCenter.default.removeObserver(obs)
    }
    let expectedGeneration = generation
    configChangeObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange,
      object: engine,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.handleConfigurationChange(generation: expectedGeneration)
      }
    }
  }

  /// Device hot-plug or sample-rate change invalidated the render graph:
  /// rebuild the engine around the same file and resume where we were.
  private func handleConfigurationChange(generation expectedGeneration: UInt) {
    guard generation == expectedGeneration, audioFile != nil else { return }
    let resumeFrame = currentFrameEstimate()
    let shouldResume = isNodePlaying
    // Phase 176 Task 3: same priority-inversion discipline as teardownGraph —
    // stop the old pair off-main, then rebuild on the main actor in order.
    let refs = SendableEngineRefs(engine: engine, node: playerNode)
    engine = nil
    playerNode = nil
    stopQueue.async { [weak self] in
      refs.node?.stop()
      refs.engine?.stop()
      Task { @MainActor [weak self] in
        guard let self,
              self.generation == expectedGeneration,
              let file = self.audioFile
        else { return }
        do {
          try self.buildGraph(for: file)
          self.scheduleSegment(from: resumeFrame, autoPlay: shouldResume, generation: expectedGeneration)
        } catch {
          print("[AVEngineBackend] ERROR: Failed to rebuild after configuration change: \(error)")
          self.teardownGraph()
          self.onFailure?()
        }
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
    guard let uid = outputDeviceUID, !uid.isEmpty else { return } // nil = system default
    Task.detached(priority: .userInitiated) {
      guard let deviceID = Self.resolveDeviceID(uid: uid) else { return } // device vanished
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
