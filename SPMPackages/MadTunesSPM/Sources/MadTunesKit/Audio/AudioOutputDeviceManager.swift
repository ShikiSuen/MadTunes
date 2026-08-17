// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

#if os(macOS)

import CoreAudio
import Observation

// MARK: - AudioOutputDevice

/// Represents a single audio output device (e.g. a DAC, headphone jack, or
/// multi-channel audio interface) as reported by CoreAudio.
public struct AudioOutputDevice: Identifiable, Hashable, Sendable {
  public let id: AudioDeviceID
  public let uid: String
  public let name: String
}

// MARK: - ListenerState

private final class ListenerState: @unchecked Sendable {
  var installed = false
  var block: AudioObjectPropertyListenerBlock?
  let lock = NSLock()

  func install(_ block: @escaping AudioObjectPropertyListenerBlock) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard !installed else { return false }
    self.block = block
    installed = true
    return true
  }

  func remove() -> AudioObjectPropertyListenerBlock? {
    lock.lock()
    defer { lock.unlock() }
    let oldBlock = block
    block = nil
    installed = false
    return oldBlock
  }
}

// MARK: - SendableListenerBlock

private struct SendableListenerBlock: @unchecked Sendable {
  let block: AudioObjectPropertyListenerBlock
}

// MARK: - AudioOutputDeviceManager

/// Phase 127: Enumerates macOS audio output devices via CoreAudio and allows
/// the caller to route AVPlayer output to a specific device by UID.
/// Phase 144: All CoreAudio API calls are now async to avoid priority inversion
/// warnings on macOS 15 + Xcode 26.3 (Intel).
@Observable
@MainActor
public final class AudioOutputDeviceManager {
  // MARK: Lifecycle

  public init() {
    Task.detached(priority: .userInitiated) {
      await self.refreshDevices()
      await self.installDeviceListChangeListener()
    }
  }

  deinit {
    guard let block = listenerState.remove() else { return }
    let sendableBlock = SendableListenerBlock(block: block)
    Task.detached(priority: .medium) {
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        DispatchQueue.main,
        sendableBlock.block
      )
    }
  }

  // MARK: Public

  /// All available audio output devices.
  public private(set) var outputDevices: [AudioOutputDevice] = []

  /// The UID of the currently selected output device, or `nil` for system default.
  public var selectedDeviceUID: String?

  /// Cached UID of the system default output device, updated during refreshDevices().
  public private(set) var cachedSystemDefaultDeviceUID: String?

  /// Refresh the list of available output devices from CoreAudio.
  public func refreshDevices() async {
    async let devicesTask = Self.fetchOutputDevices()
    async let defaultUIDTask = Self.fetchSystemDefaultDeviceUID()
    let devices = await devicesTask
    let defaultUID = await defaultUIDTask
    await MainActor.run {
      self.outputDevices = devices
      self.cachedSystemDefaultDeviceUID = defaultUID
    }
  }

  // MARK: Private

  private let listenerState = ListenerState()

  // MARK: - Static CoreAudio Helpers (nonisolated)

  private nonisolated static func performCoreAudioCall<T>(
    priority: TaskPriority = .medium,
    _ operation: @escaping @Sendable () -> T
  ) async
    -> T where T: Sendable {
    await Task.detached(priority: priority) {
      operation()
    }.value
  }

  private static func fetchSystemDefaultDeviceUID() async -> String? {
    await performCoreAudioCall {
      var deviceID = AudioDeviceID(0)
      var size = UInt32(MemoryLayout<AudioDeviceID>.size)
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      let result = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
      ) == noErr
      return result ? Self.uidForDeviceSync(deviceID) : nil
    }
  }

  private static func fetchOutputDevices() async -> [AudioOutputDevice] {
    await performCoreAudioCall {
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      var dataSize: UInt32 = 0
      guard AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
      ) == noErr else { return [] }

      let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
      var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
      guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs
      ) == noErr else { return [] }

      var devices: [AudioOutputDevice] = []
      for deviceID in deviceIDs {
        var streamAddress = AudioObjectPropertyAddress(
          mSelector: kAudioDevicePropertyStreams,
          mScope: kAudioDevicePropertyScopeOutput,
          mElement: kAudioObjectPropertyElementMain
        )
        var streamSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
          deviceID, &streamAddress, 0, nil, &streamSize
        ) == noErr, streamSize > 0 else { continue }

        guard let uid = Self.uidForDeviceSync(deviceID),
              let name = Self.nameForDeviceSync(deviceID) else { continue }

        // Phase 176 Task 5: Hide CoreAudio's transient per-process aggregates
        // (`CADefaultDeviceAggregate-<pid>-<n>`), which exist while an
        // AVAudioEngine is running; routing our own output into our own
        // engine's aggregate would be meaningless. User-created AMS
        // aggregates use other UID schemes (e.g. `~:AMS2_Aggregate:0`)
        // and stay listed.
        if uid.hasPrefix("CADefaultDeviceAggregate") { continue }

        devices.append(AudioOutputDevice(id: deviceID, uid: uid, name: name))
      }
      return devices
    }
  }

  private nonisolated static func uidForDeviceSync(_ deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var uid: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(
      deviceID, &address, 0, nil, &size, &uid
    ) == noErr else { return nil }
    return uid?.takeUnretainedValue() as String?
  }

  private nonisolated static func nameForDeviceSync(_ deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioObjectPropertyName,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var name: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(
      deviceID, &address, 0, nil, &size, &name
    ) == noErr else { return nil }
    return name?.takeUnretainedValue() as String?
  }

  private func installDeviceListChangeListener() async {
    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      Task { @MainActor [weak self] in
        await self?.refreshDevices()
      }
    }
    guard listenerState.install(block) else { return }
    let sendableBlock = SendableListenerBlock(block: block)
    let success = await Self.performCoreAudioCall(priority: .medium) {
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      return AudioObjectAddPropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        DispatchQueue.main,
        sendableBlock.block
      ) == noErr
    }
    if !success {
      _ = listenerState.remove()
    }
  }
}

#endif
