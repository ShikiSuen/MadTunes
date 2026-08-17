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
    consecutiveFailedRestarts = 0
    #if os(macOS)
    // Phase 176 Task 11: resolve the route plan off-main BEFORE building the
    // graph — a pre-attach pin must land before `engine.attach`, so the plan
    // has to be known up front.
    let expectedGeneration = generation
    let uid = outputDeviceUID
    Task.detached(priority: .medium) { [weak self] in
      let plan = Self.resolveRoutePlan(uid: uid)
      Task { @MainActor [weak self] in
        guard let self, self.generation == expectedGeneration else { return }
        self.routePlan = plan
        self.startPlayback(url: url, startAt: startAt, autoPlay: autoPlay)
      }
    }
    #else
    startPlayback(url: url, startAt: startAt, autoPlay: autoPlay)
    #endif
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
    refreshRoutePlanAndReconcile()
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
  /// Phase 176 Task 12: Bumped by every INTENTIONAL node stop (teardown,
  /// configuration-change recovery). `AVAudioPlayerNode.stop()` flushes
  /// pending `.dataPlayedBack` completions (verified: tmp/aggReproApp), and
  /// those paths deliberately do NOT bump `generation` (the config-change
  /// observer must stay valid), so segment completions carry their own epoch.
  private var segmentEpoch: UInt = 0
  private var isNodePlaying = false
  private var timeTimer: Timer?
  private var configChangeObserver: (any NSObjectProtocol)?
  /// Phase 176 Task 10: Consecutive configuration-change recoveries whose
  /// same-engine restart failed. An unattachable explicit device pin (e.g. a
  /// non-stacked aggregate) kills every rebuilt engine the moment the pin
  /// lands; without a cap, the rebuild→death cycle churns forever.
  private var consecutiveFailedRestarts = 0
  /// Phase 176 Task 3: Serial queue for blocking engine/node `stop()` calls,
  /// keeping them off the main thread and strictly ordered against each other.
  /// Phase 176 Task 9: QoS is deliberately .default — engine/node stop/start
  /// internally wait on Default-QoS audio worker threads, so running them on
  /// a higher-QoS queue trips the runtime priority-inversion diagnostic.
  private let stopQueue = DispatchQueue(
    label: "MadTunes.AVEnginePlaybackBackend.stopQueue",
    qos: .default
  )

  #if os(iOS)
  private var interruptionObserver: (any NSObjectProtocol)?
  private var wasPlayingBeforeInterruption = false
  #endif

  #if os(macOS)
  private var outputDeviceUID: String?
  /// Phase 176 Task 11: Route plan resolved for the CURRENT selection
  /// (`outputDeviceUID`); consulted whenever a graph is built.
  private var routePlan: RoutePlan = .followDefault
  /// Phase 176 Task 11: The route the CURRENT engine instance actually
  /// carries; `nil` while no engine exists. Once an output unit is pinned it
  /// can never return to native default-tracking (writing
  /// `kAudioDeviceUnknown` bricks the unit — tmp/aggMatrix2 T9), so plan
  /// changes to or from a pin are applied by rebuilding the engine.
  private var appliedPlan: RoutePlan?
  #endif

  // MARK: - Position Reporting

  /// Phase 176 Task 7: Last position sampled while the node was actually
  /// rendering. A configuration change kills render timestamps before the
  /// recovery code runs, so recovery must resume from this rather than from
  /// a fresh (already-fallen-back) estimate.
  private var lastRenderedFrame: AVAudioFramePosition = 0

  // MARK: - Output Device Routing (macOS)

  #if os(macOS)
  /// Phase 176 Task 11: Resolve the route plan for a selection UID.
  /// Off-main only (CoreAudio, Phase 144/176 Task 9 discipline).
  ///
  /// Policy (every rule verified in tmp/aggMatrix*.swift + tmp/aggProbe*.swift
  /// on macOS 26):
  /// - Explicit plain device → `pinPostStart`: in-place writes are safe there
  ///   (T2), including when the device happens to be the system default.
  /// - Explicit grup device (aggregate / multi-output, class `aagg`) →
  ///   `pinPreAttach`: post-start writes of a grup device that is the system
  ///   default kill the render thread (T5/T10/S6), and of a non-stacked
  ///   aggregate ALWAYS (T1/T8) — but a pin written BEFORE `engine.attach`
  ///   survives every combination (S13–S15).
  /// - System default (nil/empty UID) → native tracking for a plain default
  ///   (follows later default changes live, T10-fixed), but a GRUP default
  ///   must be pinned pre-attach: tracking a stacked multi-output silently
  ///   renders to its first sub-device only (tmp/aggProbe3 S7), losing the
  ///   stacked replication to the remaining sub-devices.
  /// - Unresolvable selection (device unplugged) → follow the default.
  private nonisolated static func resolveRoutePlan(uid: String?) -> RoutePlan {
    if let uid, !uid.isEmpty {
      guard let deviceID = resolveDeviceID(uid: uid) else { return .followDefault }
      return isAggregateOrMultiOutput(deviceID)
        ? .pinPreAttach(deviceID)
        : .pinPostStart(deviceID)
    }
    if let defaultID = resolveSystemDefaultOutputDeviceID(),
       isAggregateOrMultiOutput(defaultID) {
      return .pinPreAttach(defaultID)
    }
    return .followDefault
  }

  /// Phase 176 Task 11: Re-resolve `routePlan` for the stored selection and
  /// bring the running engine in line with it.
  private func refreshRoutePlanAndReconcile() {
    let uid = outputDeviceUID
    Task.detached(priority: .medium) { [weak self] in
      let plan = Self.resolveRoutePlan(uid: uid)
      Task { @MainActor [weak self] in
        guard let self, self.outputDeviceUID == uid else { return }
        self.routePlan = plan
        self.reconcileRouteWithEngine()
      }
    }
  }

  /// Phase 176 Task 11: Bring the running engine's route in line with
  /// `routePlan`. Entering/leaving a pin requires a fresh engine (a written
  /// pin can never be revoked — Task 10 — and a pre-attach pin can only land
  /// before `attach`); post-start pins are written in place.
  private func reconcileRouteWithEngine() {
    guard engine != nil else { return }
    let current = appliedPlan ?? .followDefault
    guard current != routePlan else { return }
    switch routePlan {
    case .followDefault, .pinPreAttach:
      rebuildGraphForRouteChange()
    case let .pinPostStart(deviceID):
      postStartPin(deviceID)
    }
  }

  /// Phase 176: Write an explicit pin to the RUNNING engine's output unit.
  /// Only ever used for targets proven safe for post-start writes (plain
  /// devices) — grup devices go through `pinPreAttach` instead (Task 11).
  private func postStartPin(_ deviceID: AudioDeviceID) {
    guard let engine, let audioUnit = engine.outputNode.audioUnit else { return }
    Task.detached(priority: .medium) { [weak self] in
      var newID = deviceID
      let wrote = AudioUnitSetProperty(
        audioUnit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &newID,
        UInt32(MemoryLayout<AudioDeviceID>.size)
      ) == noErr
      Task { @MainActor [weak self] in
        guard let self, self.routePlan == .pinPostStart(deviceID), wrote else { return }
        self.appliedPlan = .pinPostStart(deviceID)
      }
    }
  }

  /// Phase 176 Tasks 10–11: Re-apply `routePlan` on a fresh engine at the
  /// current position. A written pin can never be revoked on the same unit,
  /// and a pre-attach pin can only land before `attach` — both directions of
  /// such a change therefore require a rebuild. Playback resumes at the last
  /// rendered position with the playing/paused state preserved.
  private func rebuildGraphForRouteChange() {
    guard let file = audioFile else { return }
    generation &+= 1
    let resumeFrame = currentFrameEstimate()
    let shouldResume = isNodePlaying
    teardownGraph()
    do {
      audioFile = file
      fileDuration = Double(file.length) / file.processingFormat.sampleRate
      try buildGraph(for: file)
      scheduleSegment(from: resumeFrame, autoPlay: shouldResume, generation: generation)
      installConfigChangeObserver()
      startTimeTimer()
    } catch {
      print("[AVEngineBackend] ERROR: Failed to rebuild for route change: \(error)")
      teardownGraph()
      onFailure?()
    }
  }

  /// Phase 176 Task 10: Aggregate and multi-output devices share the `aagg`
  /// object class.
  private nonisolated static func isAggregateOrMultiOutput(_ deviceID: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioObjectPropertyClass,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var classID: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &classID) == noErr
    else { return false }
    return classID == kAudioAggregateDeviceClassID
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

  private func startPlayback(url: URL, startAt: TimeInterval, autoPlay: Bool) {
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

  // MARK: - Graph Management

  /// Build and start a fresh engine + player node pair for `file`.
  private func buildGraph(for file: AVAudioFile) throws {
    let engine = AVAudioEngine()
    #if os(macOS)
    // Phase 176 Task 11: a grup-device pin MUST land here — before any
    // attach/connect — the only window where pinning a grup device does not
    // kill the render thread when it is the system default, and the only
    // window a non-stacked aggregate can be attached at all
    // (tmp/aggProbe5 S13–S15). The unit runs no IO yet, so this write cannot
    // wait on audio worker threads (no priority inversion despite the main
    // thread).
    appliedPlan = .followDefault
    if case let .pinPreAttach(deviceID) = routePlan,
       let unit = engine.outputNode.audioUnit {
      var newID = deviceID
      if AudioUnitSetProperty(
        unit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &newID,
        UInt32(MemoryLayout<AudioDeviceID>.size)
      ) == noErr {
        appliedPlan = routePlan
      }
    }
    #endif
    let node = AVAudioPlayerNode()
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
    engine.mainMixerNode.outputVolume = volume
    self.engine = engine
    playerNode = node
    #if os(macOS)
    if case let .pinPostStart(deviceID) = routePlan {
      postStartPin(deviceID)
    }
    #endif
    engine.prepare()
    try engine.start()
  }

  private func teardownGraph() {
    // Phase 176 Task 12: invalidate the pending segment completion before
    // the async node.stop() below can flush it (stop fires completions).
    segmentEpoch &+= 1
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
    #if os(macOS)
    appliedPlan = nil
    #endif
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
    // Phase 176 Task 12: capture the segment epoch alongside the generation.
    let epoch = segmentEpoch
    node.scheduleSegment(
      file,
      startingFrame: startFrame,
      frameCount: AVAudioFrameCount(remaining),
      at: nil,
      completionCallbackType: .dataPlayedBack
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self,
              self.generation == expectedGeneration,
              self.segmentEpoch == epoch
        else { return }
        // Phase 176 Task 12: this completion is NOT a trustworthy natural-end
        // signal. An intentional stop flushes it (tmp/aggReproApp — epoch
        // guard above covers that), and a DEAD render thread fires it early
        // on its own (tmp/completionProbe X). Trust it only when the render
        // actually reached the segment end; otherwise treat it as a render
        // failure and run configuration-change recovery. The recovery's
        // restart SUCCEEDS even when the render stays dead, so the strike
        // has to be counted here, at the symptom.
        let fileLength = self.audioFile?.length ?? 0
        let sampleRate = self.audioFile?.processingFormat.sampleRate ?? 44_100
        let tolerance = AVAudioFramePosition(sampleRate / 2)
        guard fileLength > 0,
              self.currentFrameEstimate() >= fileLength - tolerance
        else {
          self.segmentEpoch &+= 1
          self.consecutiveFailedRestarts &+= 1
          guard self.consecutiveFailedRestarts < 3 else {
            print("[AVEngineBackend] ERROR: Render died repeatedly (false natural-end); giving up.")
            self.teardownGraph()
            self.onFailure?()
            return
          }
          self.performConfigurationChangeRecovery(generation: expectedGeneration)
          return
        }
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
          // Phase 176 Task 12: advancing render = the pipeline is healthy;
          // clear the recovery strike counter here (restart success alone
          // proves nothing — the render can stay dead through it).
          if rendered > self.lastRenderedFrame {
            self.consecutiveFailedRestarts = 0
          }
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
    #if os(macOS)
    // Phase 176 Task 11: re-resolve the route plan first — a configuration
    // change often IS a default-device change, and the fresh plan decides
    // how a potential rebuild must route.
    let uid = outputDeviceUID
    Task.detached(priority: .medium) { [weak self] in
      let plan = Self.resolveRoutePlan(uid: uid)
      Task { @MainActor [weak self] in
        guard let self, self.generation == expectedGeneration else { return }
        self.routePlan = plan
        self.performConfigurationChangeRecovery(generation: expectedGeneration)
      }
    }
    #else
    performConfigurationChangeRecovery(generation: expectedGeneration)
    #endif
  }

  private func performConfigurationChangeRecovery(generation expectedGeneration: UInt) {
    let resumeFrame = currentFrameEstimate()
    let shouldResume = isNodePlaying
    // Phase 176 Task 12: invalidate the pending segment completion BEFORE the
    // stops below flush it — a flushed completion must not read as natural end.
    segmentEpoch &+= 1
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
          // Phase 176 Task 10: three strikes. If every rebuilt engine dies
          // as soon as its route is applied (a device that errors on attach,
          // an unplug storm), the rebuild→death cycle would churn forever
          // uncapped. Cap it and surface a playback failure instead.
          self.consecutiveFailedRestarts &+= 1
          guard self.consecutiveFailedRestarts < 3 else {
            print("[AVEngineBackend] ERROR: Configuration-change recovery failed repeatedly; giving up.")
            self.teardownGraph()
            self.onFailure?()
            return
          }
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
        // Phase 176 Task 12: the strike counter is deliberately NOT reset
        // here — a restart can succeed while the render stays dead. The
        // 0.25s timer resets it upon observing actual render progress.
        self.scheduleSegment(from: resumeFrame, autoPlay: shouldResume, generation: expectedGeneration)
        #if os(macOS)
        // The engine kept its route through the restart, but the fresh plan
        // may disagree now (e.g. the default moved onto/off a grup device).
        self.reconcileRouteWithEngine()
        #endif
      }
    }
  }

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

#if os(macOS)

// MARK: - RoutePlan

/// Phase 176 Task 11: How the output route for the current selection must be
/// established. See `resolveRoutePlan(uid:)` for the policy.
private enum RoutePlan: Equatable {
  /// No explicit write; the output unit natively tracks the system default.
  case followDefault
  /// Pin written before `engine.attach` — required for grup devices
  /// (aggregates / multi-outputs).
  case pinPreAttach(AudioDeviceID)
  /// Pin written onto the running engine — safe for plain devices only.
  case pinPostStart(AudioDeviceID)
}

#endif
