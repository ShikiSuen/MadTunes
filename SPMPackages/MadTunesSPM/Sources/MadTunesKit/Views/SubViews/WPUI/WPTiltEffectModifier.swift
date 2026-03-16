// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPTiltEffectModifier

/// Phase 75: Windows Phone-style tilt effect on touch.
/// Applies a subtle 3D rotation that follows the touch position.
struct WPTiltEffectModifier: ViewModifier {
  // MARK: Internal

  func body(content: Content) -> some View {
    content
      .rotation3DEffect(
        .degrees(isTilted ? 3 : 0),
        axis: (x: tiltAxisX, y: tiltAxisY, z: 0),
        perspective: 0.5
      )
      .scaleEffect(isTilted ? 0.97 : 1.0)
      .animation(.easeOut(duration: 0.15), value: isTilted)
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            if !isTilted {
              // Compute tilt axis from touch position relative to center.
              let dx = value.location.x - value.startLocation.x
              let dy = value.location.y - value.startLocation.y
              tiltAxisX = dy < 0 ? 1 : -1
              tiltAxisY = dx < 0 ? -1 : 1
              isTilted = true
            }
          }
          .onEnded { _ in
            isTilted = false
          }
      )
  }

  // MARK: Private

  @State private var isTilted = false
  @State private var tiltAxisX: CGFloat = 0
  @State private var tiltAxisY: CGFloat = 0
}

extension View {
  /// Applies Windows Phone-style tilt touch feedback.
  func wpTiltEffect() -> some View {
    modifier(WPTiltEffectModifier())
  }
}
