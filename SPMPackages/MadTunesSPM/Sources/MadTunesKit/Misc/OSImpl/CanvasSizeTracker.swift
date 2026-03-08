// (c) 2024 and onwards Pizza Studio (MIT License).
// ====================
// This code is released under the SPDX-License-Identifier: `MIT License`.

// Author: Shiki Suen

import SwiftUI

// MARK: - CanvasSizeTracker

@available(iOS 16.0, macCatalyst 16.0, *)
private struct CanvasSizeTracker: ViewModifier {
  // MARK: Lifecycle

  public init(handler: @escaping (CGSize) -> Void, debounceDelay: TimeInterval = 0.1) {
    self.handler = handler
    self._sizeState = .init(wrappedValue: SizeState(debounceDelay: debounceDelay))
  }

  // MARK: Public

  public func body(content: Content) -> some View {
    content
      .background {
        SizeReadingLayout(onChange: { size in
          Task { @MainActor in
            sizeState.update(width: size.width, height: size.height)
            dispatchHandlerIfValid()
          }
        }) {
          Color.clear
        }
      }
  }

  // MARK: Private

  @State private var sizeState: SizeState

  private let handler: (CGSize) -> Void

  private func dispatchHandlerIfValid() {
    if sizeState.size.width > 0, sizeState.size.height > 0 {
      sizeState.debounce { size in
        handler(size)
      }
    }
  }
}

// MARK: - SizeReadingLayout

/// A pure Layout that reads size without interfering with the default layout behavior.
@available(iOS 16.0, macCatalyst 16.0, *)
private struct SizeReadingLayout: Layout {
  // MARK: Lifecycle

  init(onChange: @Sendable @escaping (CGSize) -> Void) {
    self.onChange = .init(onChange)
  }

  // MARK: Internal

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout Void) -> CGSize {
    subviews.first?.sizeThatFits(proposal) ?? .zero
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout Void) {
    subviews.first?.place(at: bounds.origin, proposal: proposal)
    onChange.withLock { $0(bounds.size) }
  }

  // MARK: Private

  private let onChange: NSMutex<(CGSize) -> Void>
}

// MARK: - SizeState

/// This doesn't need to be @Observable.
@MainActor
private class SizeState {
  // MARK: Lifecycle

  init(debounceDelay: TimeInterval) {
    self.debounceDelay = debounceDelay
  }

  // MARK: Internal

  var size: CGSize = .zero

  func update(width: CGFloat? = nil, height: CGFloat? = nil) {
    if let width = width, width.isFinite, width >= 0 {
      size.width = width
    }
    if let height = height, height.isFinite, height >= 0 {
      size.height = height
    }
  }

  func debounce(_ action: @escaping @MainActor (CGSize) -> Void) {
    task?.cancel()
    task = Task { @MainActor [weak self] in
      guard let self else { return }
      try await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
      try Task.checkCancellation()
      action(size)
    }
  }

  // MARK: Private

  private var task: Task<Void, Error>?
  private let debounceDelay: TimeInterval
}

@available(iOS 16.0, macCatalyst 16.0, *)
extension View {
  @ViewBuilder
  public func trackCanvasSize(
    debounceDelay: TimeInterval = 0.1,
    handler: @escaping (CGSize) -> Void
  )
    -> some View {
    modifier(CanvasSizeTracker(handler: handler, debounceDelay: debounceDelay))
  }
}
