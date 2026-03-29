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

// MARK: - AudioOutputDeviceManager

/// Phase 127: Enumerates macOS audio output devices via CoreAudio and allows
/// the caller to route AVPlayer output to a specific device by UID.
@Observable
@MainActor
public final class AudioOutputDeviceManager {
  // MARK: Lifecycle

  public init() {
    refreshDevices()
    installDeviceListChangeListener()
  }

  deinit {
    MainActor.assumeIsolated {
      removeDeviceListChangeListener()
    }
  }

  // MARK: Public

  /// All available audio output devices.
  public private(set) var outputDevices: [AudioOutputDevice] = []

  /// The UID of the currently selected output device, or `nil` for system default.
  public var selectedDeviceUID: String?

  /// Returns the UID of the system default output device, if obtainable.
  public var systemDefaultDeviceUID: String? {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
    ) == noErr else { return nil }
    return uidForDevice(deviceID)
  }

  /// Refresh the list of available output devices from CoreAudio.
  public func refreshDevices() {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0
    // WARN: [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions.
    guard AudioObjectGetPropertyDataSize(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
    ) == noErr else { return }

    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
    guard AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs
    ) == noErr else { return }

    var devices: [AudioOutputDevice] = []
    for deviceID in deviceIDs {
      // Check if this device has output streams.
      var streamAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
      )
      var streamSize: UInt32 = 0
      guard AudioObjectGetPropertyDataSize(
        deviceID, &streamAddress, 0, nil, &streamSize
      ) == noErr, streamSize > 0 else { continue }

      guard let uid = uidForDevice(deviceID),
            let name = nameForDevice(deviceID) else { continue }

      devices.append(AudioOutputDevice(id: deviceID, uid: uid, name: name))
    }
    outputDevices = devices
  }

  // MARK: Private

  private var listenerInstalled = false
  private var listenerBlock: AudioObjectPropertyListenerBlock?

  private func uidForDevice(_ deviceID: AudioDeviceID) -> String? {
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

  private func nameForDevice(_ deviceID: AudioDeviceID) -> String? {
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

  private func installDeviceListChangeListener() {
    guard !listenerInstalled else { return }
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      Task { @MainActor in
        self?.refreshDevices()
      }
    }
    let status = AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      DispatchQueue.main,
      block
    )
    if status == noErr {
      listenerBlock = block
      listenerInstalled = true
    }
  }

  private func removeDeviceListChangeListener() {
    guard listenerInstalled else { return }
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    if let block = listenerBlock {
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        DispatchQueue.main,
        block
      )
    }
    listenerBlock = nil
    listenerInstalled = false
  }
}

#endif
