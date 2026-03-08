// (c) 2024 and onwards Pizza Studio (MIT License).
// ====================
// This code is released under the SPDX-License-Identifier: `MIT License`.

// Author: Bill Haku & Shiki Suen

import Foundation
import SwiftUI

// MARK: - OnAppBecomeActiveModifier

/// A ViewModifier that adds an action to be performed whenever an app comes to active state.
@available(iOS 16.0, macCatalyst 16.0, macOS 13.0, *)
private struct OnAppBecomeActiveModifier: ViewModifier {
  @Environment(\.scenePhase) private var scenePhase: ScenePhase

  /// When `true`, execute immediately; otherwise debounce the action with a 60-second window.
  let forced: Bool

  /// A closure that holds the action to be performed on becoming active.
  let action: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    content
      .onAppear {
        if OS.type == .macOS {
          if #unavailable(iOS 18.0, macCatalyst 18.0, macOS 15.0, watchOS 11.0) {
            triggerAction()
          }
        }
      }
      .react(to: scenePhase) { _, scenePhase in
        if OS.type != .macOS {
          if scenePhase == .active {
            triggerAction()
          }
        }
      }
  }

  private func triggerAction() {
    if forced {
      action()
    } else {
      Task {
        await debouncer.debounce {
          await MainActor.run {
            action()
          }
        }
      }
    }
  }

  // MARK: Private

  private let debouncer: Debouncer = .init(delay: 60)
}

// MARK: - OnAppBecomeActiveModifierMac

@available(iOS 18.0, macCatalyst 18.0, macOS 15.0, watchOS 11.0, *)
private struct OnAppBecomeActiveModifierMac: ViewModifier {
  // MARK: Lifecycle

  public init(forced: Bool = true, action: @escaping () -> Void) {
    self.forced = forced
    self.action = action
  }

  // MARK: Internal

  @Environment(\.appearsActive) var appearsActive

  let forced: Bool

  let action: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    content
      .react(to: appearsActive) { oldValue, newValue in
        if newValue, oldValue != newValue {
          if forced {
            action()
          } else {
            Task {
              await debouncer.debounce {
                await MainActor.run {
                  action()
                }
              }
            }
          }
        }
      }
  }

  // MARK: Private

  private let debouncer: Debouncer = .init(delay: 60)
}

// MARK: - OnAppEnterBackgroundModifier

@available(iOS 16.0, macCatalyst 16.0, macOS 13.0, *)
private struct OnAppEnterBackgroundModifier: ViewModifier {
  @Environment(\.scenePhase) private var scenePhase: ScenePhase

  let action: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    content
      .react(to: scenePhase) { _, scenePhase in
        if scenePhase == .background {
          action()
        }
      }
  }
}

// MARK: - OnAppBecomeInactiveModifier

@available(iOS 16.0, macCatalyst 16.0, *)
private struct OnAppBecomeInactiveModifier: ViewModifier {
  @Environment(\.scenePhase) private var scenePhase: ScenePhase

  let action: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    content
      .react(to: scenePhase) { _, scenePhase in
        if scenePhase == .inactive {
          action()
        }
      }
  }
}

@available(iOS 16.0, macCatalyst 16.0, macOS 13.0, *)
extension View {
  @ViewBuilder
  public func onAppBecomeActive(
    debounced: Bool = true,
    perform action: @escaping () -> Void
  )
    -> some View {
    if #available(iOS 18.0, macCatalyst 18.0, macOS 15.0, watchOS 11.0, *) {
      if OS.type == .macOS {
        modifier(OnAppBecomeActiveModifierMac(forced: debounced, action: action))
      } else {
        modifier(OnAppBecomeActiveModifier(forced: debounced, action: action))
      }
    } else {
      modifier(OnAppBecomeActiveModifier(forced: debounced, action: action))
    }
  }

  @ViewBuilder
  public func onAppEnterBackground(perform action: @escaping () -> Void) -> some View {
    modifier(OnAppEnterBackgroundModifier(action: action))
  }

  @ViewBuilder
  public func onAppBecomeInactive(perform action: @escaping () -> Void) -> some View {
    modifier(OnAppBecomeInactiveModifier(action: action))
  }
}
