// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPTiltEffectModifier

/// Phase 75: Windows Phone-style tilt effect on touch.
/// Applies a subtle 3D rotation that follows the touch position.
///
/// Phase 79: Replaced DragGesture(minimumDistance: 0) with
/// onLongPressGesture(pressing:) to avoid intercepting ScrollView
/// vertical scrolling when tiles fill the entire viewport.
struct WPTiltEffectModifier: ViewModifier {
  // MARK: Internal

  func body(content: Content) -> some View {
    content
      .rotation3DEffect(
        .degrees(isTilted ? 3 : 0),
        axis: (x: -0.5, y: 0.5, z: 0),
        perspective: 0.5
      )
      .scaleEffect(isTilted ? 0.97 : 1.0)
      .animation(.easeOut(duration: 0.15), value: isTilted)
      .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
        isTilted = pressing
      }, perform: {})
  }

  // MARK: Private

  @State private var isTilted = false
}

extension View {
  /// Applies Windows Phone-style tilt touch feedback.
  func wpTiltEffect() -> some View {
    modifier(WPTiltEffectModifier())
  }
}
