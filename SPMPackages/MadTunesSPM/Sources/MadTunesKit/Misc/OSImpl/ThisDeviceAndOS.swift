// (c) 2024 and onwards Pizza Studio (MIT License).
// ====================
// This code is released under the SPDX-License-Identifier: `MIT License`.

// Author: Shiki Suen

import Foundation
#if canImport(IOKit)
import IOKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - ThisDevice

public enum ThisDevice {}

extension ThisDevice {
  // MARK: Public

  public static let modelIdentifier: String = getModelIdentifier()

  public nonisolated static func getModelIdentifier() -> String {
    #if os(macOS)
    let service: io_service_t = IOServiceGetMatchingService(
      kIOMainPortDefault,
      IOServiceMatching("IOPlatformExpertDevice")
    )
    if let model = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0) {
      if let modelStr = model.takeRetainedValue() as? String {
        IOObjectRelease(service)
        return modelStr
      }
    }
    IOObjectRelease(service)
    return "UnknownMac"
    #elseif os(iOS) || targetEnvironment(macCatalyst)
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children
      .reduce("") { identifier, element in
        guard let value = element.value as? Int8,
              value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
      }
    return identifier
    #elseif os(watchOS)
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children
      .reduce("") { identifier, element in
        guard let value = element.value as? Int8,
              value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
      }
    return identifier
    #endif
  }

  /// Detects whether the current Mac is running on an Intel processor.
  /// On non-macOS/macCatalyst platforms, this always returns `false`.
  public static let isIntelProcessor: Bool = {
    #if os(watchOS)
    return false
    #elseif os(macOS) || targetEnvironment(macCatalyst)
    var sysinfo = utsname()
    uname(&sysinfo)
    let machine = withUnsafePointer(to: &sysinfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(validatingCString: $0)
      }
    }
    return machine?.contains("x86_64") == true
    #else
    return false
    #endif
  }()
}

// MARK: - OS

public enum OS: Int, Sendable {
  case macOS = 0
  case iPhoneOS = 1
  case iPadOS = 2
  case watchOS = 3
  case tvOS = 4

  // MARK: Public

  public static let isAppKit: Bool = {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    return true
    #else
    return false
    #endif
  }()

  public static let liquidGlassThemeSuspected: Bool = {
    if let infoDict = Bundle.main.infoDictionary {
      let verStr = (infoDict["DTPlatformVersion"] as? String)?.prefix(4) ?? "_"
      if let verDouble = Double(verStr) {
        if verDouble < 26 { return false }
        let uiCompat = infoDict["UIDesignRequiresCompatibility"] as? Bool
        if uiCompat == true { return false }
      }
    }
    #if os(macOS)
    return if #unavailable(macOS 26) { false } else { true }
    #elseif os(watchOS)
    return if #unavailable(watchOS 26) { false } else { true }
    #elseif os(tvOS)
    return if #unavailable(tvOS 26) { false } else { true }
    #elseif os(iOS)
    #if targetEnvironment(simulator)
    return if #unavailable(iOS 26) { false } else { true }
    #elseif targetEnvironment(macCatalyst)
    return if #unavailable(macCatalyst 26) { false } else { true }
    #else
    return if #unavailable(iOS 26) { false } else { true }
    #endif
    #endif
  }()

  public static let isCatalyst: Bool = {
    #if targetEnvironment(macCatalyst)
    return true
    #else
    return false
    #endif
  }()

  public static var type: OS { OSTypeCache.shared.value }

  public static func initializeOSType() {
    _ = OS.type
  }
}

// MARK: - OSTypeCache

private final class OSTypeCache: @unchecked Sendable {
  // MARK: Internal

  static let shared = OSTypeCache()

  var value: OS {
    lock.lock()
    defer { lock.unlock() }

    if let cached = _cachedValue {
      return cached
    }

    let computed = Self.computeOSType()
    _cachedValue = computed
    return computed
  }

  // MARK: Private

  private static var maybePad: Bool {
    #if os(iOS) || targetEnvironment(macCatalyst)
    if ThisDevice.getModelIdentifier().contains("iPad") { return true }
    if Thread.isMainThread {
      return MainActor.assumeIsolated {
        UIDevice.current.userInterfaceIdiom == .pad
      }
    }
    return DispatchQueue.main.sync {
      UIDevice.current.userInterfaceIdiom == .pad
    }
    #else
    return false
    #endif
  }

  private var _cachedValue: OS?
  private let lock = NSLock()

  private static func computeOSType() -> OS {
    guard !ProcessInfo.processInfo.isiOSAppOnMac else { return .macOS }
    #if DEBUG
    if ProcessInfo.processInfo.environment["SIMULATE_MAC_ENV"] == "YES" { return .macOS }
    #endif
    #if os(macOS)
    return .macOS
    #elseif os(watchOS)
    return .watchOS
    #elseif os(tvOS)
    return .tvOS
    #elseif os(iOS)
    #if targetEnvironment(simulator)
    return maybePad ? .iPadOS : .iPhoneOS
    #elseif targetEnvironment(macCatalyst)
    return .macOS
    #else
    return maybePad ? .iPadOS : .iPhoneOS
    #endif
    #endif
  }
}
