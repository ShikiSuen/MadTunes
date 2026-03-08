// (c) 2024 and onwards Pizza Studio (MIT License).
// ====================
// This code is released under the SPDX-License-Identifier: `MIT License`.

// Author: Shiki Suen

import Combine
import Foundation
import SwiftUI

extension View {
  @ViewBuilder
  public func react<V>(
    to value: V,
    initial: Bool = false,
    _ action: @escaping (V, V) -> Void
  )
    -> some View where V: Equatable {
    if #available(iOS 17.0, macCatalyst 17.0, macOS 14.0, watchOS 10.0, *) {
      onChange(of: value, initial: initial, action)
    } else {
      modifier(
        ComparableReactModifier(value: value, initial: initial, action: action)
      )
    }
  }

  @ViewBuilder
  public func react<V>(
    to value: V,
    initial: Bool = false,
    _ action: @escaping () -> Void
  )
    -> some View where V: Equatable {
    if #available(iOS 17.0, macCatalyst 17.0, macOS 14.0, watchOS 10.0, *) {
      onChange(of: value, initial: initial, action)
    } else {
      modifier(
        ReactModifier(value: value, initial: initial, action: action)
      )
    }
  }
}

// MARK: - ComparableReactModifier

private struct ComparableReactModifier<V: Equatable>: ViewModifier {
  // MARK: Lifecycle

  init(value: V, initial: Bool, action: @escaping (V, V) -> Void) {
    self.value = value
    self.initial = initial
    self.action = action
    self._lastValue = State(initialValue: value)
  }

  // MARK: Internal

  let value: V
  let initial: Bool
  let action: (V, V) -> Void

  func body(content: Content) -> some View {
    content
      .onReceive(Just(value)) { newValue in
        guard !isInitialRun || initial else {
          lastValue = newValue
          isInitialRun = false
          return
        }

        if newValue != lastValue {
          action(lastValue, newValue)
          lastValue = newValue
        }

        isInitialRun = false
      }
  }

  // MARK: Private

  @State private var lastValue: V
  @State private var isInitialRun = true
}

// MARK: - ReactModifier

private struct ReactModifier<V: Equatable>: ViewModifier {
  // MARK: Lifecycle

  init(value: V, initial: Bool, action: @escaping () -> Void) {
    self.value = value
    self.initial = initial
    self.action = action
    self._lastValue = State(initialValue: value)
  }

  // MARK: Internal

  let value: V
  let initial: Bool
  let action: () -> Void

  func body(content: Content) -> some View {
    content
      .onReceive(Just(value)) { newValue in
        guard !isInitialRun || initial else {
          lastValue = newValue
          isInitialRun = false
          return
        }

        if newValue != lastValue {
          action()
          lastValue = newValue
        }

        isInitialRun = false
      }
  }

  // MARK: Private

  @State private var lastValue: V
  @State private var isInitialRun = true
}
