// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

// Phase 151: Redirects unmodified vertical scroll wheel events to horizontal
// scrolling for the nearest ancestor scroll view. Suppressed when modifier
// keys are held or when the cursor is over a child scroll view.

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import SwiftUI

// MARK: - View Extension

extension View {
  /// Phase 151: Redirects unmodified vertical scroll wheel events to horizontal
  /// scrolling on the nearest ancestor NSScrollView.
  func redirectsVerticalScrollWheelToHorizontal() -> some View {
    background(AppKitScrollWheelRedirectorRepresentable().allowsHitTesting(false))
  }
}

// MARK: - AppKitScrollWheelRedirectorRepresentable

private struct AppKitScrollWheelRedirectorRepresentable: NSViewRepresentable {
  func makeNSView(context _: Context) -> AppKitScrollWheelRedirectorView {
    AppKitScrollWheelRedirectorView()
  }

  func updateNSView(_: AppKitScrollWheelRedirectorView, context _: Context) {}
}

// MARK: - AppKitScrollWheelRedirectorView

final class AppKitScrollWheelRedirectorView: NSView {
  // MARK: Internal

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    if newWindow == nil, let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
      targetScrollView = nil
    }
    super.viewWillMove(toWindow: newWindow)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil {
      install()
    }
  }

  // MARK: Private

  private weak var targetScrollView: NSScrollView?
  private var monitor: Any?

  private func install() {
    guard monitor == nil else { return }
    guard let scrollView = ancestorScrollView() else { return }
    targetScrollView = scrollView
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
      guard let self else { return event }
      return self.handleLocalScrollWheel(event)
    }
  }

  private func handleLocalScrollWheel(_ event: NSEvent) -> NSEvent? {
    guard let sv = targetScrollView, let hostWindow = window else { return event }
    guard event.window === hostWindow else { return event }
    guard eventHasNoModifierFlags(event) else { return event }

    let loc = event.locationInWindow
    guard let hitView = hostWindow.contentView?.hitTest(loc) else { return event }
    guard isDescendant(hitView, of: sv) else { return event }
    if hasChildScrollView(hitView, below: sv) {
      // Phase 151: Keep native vertical scrolling inside expanded album pane.
      return event
    }

    let dy = event.scrollingDeltaY
    guard dy != 0 else { return event }

    // Phase 151: Amplify scroll amount to match Shift+Wheel behavior.
    let amplifiedDy = dy * 10.0

    let clip = sv.contentView
    let contentWidth = sv.documentView?.frame.width ?? clip.documentRect.width
    let maxX = max(0, contentWidth - clip.bounds.width)
    var newX = clip.bounds.origin.x - amplifiedDy
    newX = min(max(0, newX), maxX)

    guard newX != clip.bounds.origin.x else { return event }
    clip.setBoundsOrigin(NSPoint(x: newX, y: clip.bounds.origin.y))
    sv.reflectScrolledClipView(clip)
    return nil
  }

  private func eventHasNoModifierFlags(_ event: NSEvent) -> Bool {
    let relevantFlags = event.modifierFlags.intersection([
      .shift,
      .control,
      .option,
      .command,
      .function,
    ])
    return relevantFlags.isEmpty
  }

  private func ancestorScrollView() -> NSScrollView? {
    var v: NSView? = superview
    while let current = v {
      if let sv = current as? NSScrollView {
        return sv
      }
      v = current.superview
    }
    return nil
  }

  private func isDescendant(_ view: NSView, of boundary: NSScrollView) -> Bool {
    var v: NSView? = view
    while let current = v {
      if current === boundary {
        return true
      }
      v = current.superview
    }
    return false
  }

  /// Walk from `view` up to (but excluding) `boundary`; return true if any
  /// intermediate ancestor is an NSScrollView (e.g. expanded album track list).
  private func hasChildScrollView(_ view: NSView, below boundary: NSScrollView) -> Bool {
    var v: NSView? = view
    while let current = v, current !== boundary {
      if current is NSScrollView {
        return true
      }
      v = current.superview
    }
    return false
  }
}

#elseif canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - View Extension

extension View {
  /// Phase 151: Redirects unmodified vertical scroll wheel events to horizontal
  /// scrolling on the nearest ancestor UIScrollView.
  func redirectsVerticalScrollWheelToHorizontal() -> some View {
    background(ScrollWheelRedirectorRepresentable().allowsHitTesting(false))
  }
}

// MARK: - ScrollWheelRedirectorRepresentable

private struct ScrollWheelRedirectorRepresentable: UIViewRepresentable {
  func makeUIView(context _: Context) -> ScrollWheelRedirectorView {
    ScrollWheelRedirectorView()
  }

  func updateUIView(_: ScrollWheelRedirectorView, context _: Context) {}
}

// MARK: - ScrollWheelRedirectGR

/// Phase 151: Marker subclass enabling deduplication on the target scroll view.
private final class ScrollWheelRedirectGR: UIPanGestureRecognizer {}

// MARK: - ScrollWheelRedirectorView

final class ScrollWheelRedirectorView: UIView {
  // MARK: Lifecycle

  deinit {
    if let gr = installedGR, let sv = targetScrollView {
      sv.removeGestureRecognizer(gr)
    }
  }

  // MARK: Internal

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil { install() }
  }

  // MARK: Fileprivate

  /// Walk from `view` up to (but excluding) `boundary`; return true if any
  /// intermediate ancestor is a UIScrollView (e.g. the expanded‐album track list).
  fileprivate func hasChildScrollView(_ view: UIView, below boundary: UIScrollView) -> Bool {
    var v: UIView? = view
    while let current = v, current !== boundary {
      if current is UIScrollView { return true }
      v = current.superview
    }
    return false
  }

  // MARK: Private

  private weak var targetScrollView: UIScrollView?
  private var installedGR: ScrollWheelRedirectGR?

  private func install() {
    guard installedGR == nil else { return }
    guard let scrollView = ancestorScrollView() else { return }
    // Deduplicate: another representable instance may have already installed a GR.
    let alreadyInstalled = (scrollView.gestureRecognizers ?? []).contains { $0 is ScrollWheelRedirectGR }
    guard !alreadyInstalled else { return }

    targetScrollView = scrollView
    let gr = ScrollWheelRedirectGR(target: self, action: #selector(scrollWheelPanned(_:)))
    gr.allowedScrollTypesMask = [.continuous, .discrete]
    gr.cancelsTouchesInView = false
    gr.delaysTouchesEnded = false
    gr.delegate = self
    scrollView.addGestureRecognizer(gr)
    installedGR = gr
  }

  @objc
  private func scrollWheelPanned(_ gr: UIPanGestureRecognizer) {
    guard let sv = gr.view as? UIScrollView else { return }
    let dy = gr.translation(in: sv).y
    gr.setTranslation(.zero, in: sv)

    // Phase 151: Suppress if modifier key pressed mid-gesture
    // or cursor moved over a child scroll view.
    guard ModifierKeyMonitor.shared.currentModifiers.isEmpty else { return }
    let loc = gr.location(in: sv)
    if let hit = sv.hitTest(loc, with: nil), hasChildScrollView(hit, below: sv) {
      return
    }

    var x = sv.contentOffset.x - dy
    let maxX = max(0, sv.contentSize.width - sv.bounds.width)
    x = max(0, min(maxX, x))
    sv.contentOffset.x = x
  }

  private func ancestorScrollView() -> UIScrollView? {
    var v: UIView? = superview
    while let current = v {
      if let sv = current as? UIScrollView { return sv }
      v = current.superview
    }
    return nil
  }
}

// MARK: - UIGestureRecognizerDelegate

extension ScrollWheelRedirectorView: UIGestureRecognizerDelegate {
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard ModifierKeyMonitor.shared.currentModifiers.isEmpty else { return false }
    guard let sv = gestureRecognizer.view as? UIScrollView else { return false }
    let loc = gestureRecognizer.location(in: sv)
    if let hit = sv.hitTest(loc, with: nil), hasChildScrollView(hit, below: sv) {
      return false
    }
    return true
  }

  func gestureRecognizer(
    _: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
  )
    -> Bool {
    true
  }
}

#else

// MARK: - No-op fallback for non-UIKit platforms.

import SwiftUI

extension View {
  func redirectsVerticalScrollWheelToHorizontal() -> some View {
    self
  }
}
#endif
