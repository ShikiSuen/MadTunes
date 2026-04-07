// This implementation is considered as copyleft from public domain.

import GameController
import SwiftUI

@MainActor
@Observable
final class ModifierKeyMonitor {
  // MARK: Lifecycle

  private init() {
    setupObservers()
    setupKeyboardListener()
  }

  // MARK: Internal

  static let shared = ModifierKeyMonitor()

  private(set) var currentModifiers: EventModifiers = []

  func setupKeyboardListener() {
    guard let keyboardInput = GCKeyboard.coalesced?.keyboardInput else { return }

    // GCPhysicalInputProfile.handlerQueue defaults to DispatchQueue.main,
    // so keyChangedHandler already fires on the main thread.
    // Use assumeIsolated to update state synchronously (no async hop).
    keyboardInput.keyChangedHandler = { _, _, keyCode, pressed in
      MainActor.assumeIsolated {
        ModifierKeyMonitor.shared.handleKeyChange(keyCode: keyCode, isPressed: pressed)
      }
    }
  }

  // MARK: Private

  private var shiftCount = 0

  private func setupObservers() {
    NotificationCenter.default.addObserver(
      forName: .GCKeyboardDidConnect,
      object: nil,
      queue: .main
    ) { _ in
      MainActor.assumeIsolated {
        ModifierKeyMonitor.shared.setupKeyboardListener()
      }
    }

    // 窗口失去焦点时必须重置，因为窗口后台时抓不到 KeyUp 事件
    let resignNotification = NSNotification.Name("NSWindowDidResignMainNotification")
    NotificationCenter.default.addObserver(
      forName: resignNotification,
      object: nil,
      queue: .main
    ) { _ in
      MainActor.assumeIsolated {
        ModifierKeyMonitor.shared.currentModifiers = []
        ModifierKeyMonitor.shared.shiftCount = 0
      }
    }
  }

  private func handleKeyChange(keyCode: GCKeyCode, isPressed: Bool) {
    // 根据 keyCode 手动增删修饰键状态
    switch keyCode {
    case .leftGUI, .rightGUI:
      update(modifier: .command, isPressed: isPressed)
    case .leftShift, .rightShift:
      shiftCount += isPressed ? 1 : -1
      shiftCount = max(0, shiftCount)
      if shiftCount > 0 {
        currentModifiers.insert(.shift)
      } else {
        currentModifiers.remove(.shift)
      }
    case .leftControl, .rightControl:
      update(modifier: .control, isPressed: isPressed)
    case .leftAlt, .rightAlt: // GameController 中 Option 键通常对应 Alt
      update(modifier: .option, isPressed: isPressed)
    // Note: CapsLock is intentionally excluded to avoid false positives.
    default:
      break
    }
  }

  private func update(modifier: EventModifiers, isPressed: Bool) {
    if isPressed {
      currentModifiers.insert(modifier)
    } else {
      currentModifiers.remove(modifier)
    }
  }
}
