// (c) 2024 and onwards Pizza Studio (MIT License).
// ====================
// This code is released under the SPDX-License-Identifier: `MIT License`.

// Author: Shiki Suen

import SwiftUI

struct GlassyAlbumOverlay: View {
  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  var body: some View {
    ZStack {
      // 1. Top Highlight Shape with specific gradient and blend mode
      TopGlassHighlight()
        .fill(LinearGradient(
          gradient: Gradient(colors: [.white.opacity(0.85), .white.opacity(0.1)]),
          startPoint: .top,
          endPoint: .bottom
        ))
        .blendMode(.screen) // Screen mode is key for highlights
        // no fixed aspect ratio – allow the parent to size freely
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      // 2. Bottom Shadow Shape with subtle gradient to provide depth
      BottomGlassShadow()
        .fill(LinearGradient(
          gradient: Gradient(colors: [.clear, .black.opacity(0.15)]),
          startPoint: .top,
          endPoint: .bottom
        ))
        // allow the shadow to stretch with its container
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .allowsHitTesting(false)
  }

  // MARK: Private

  private struct TopGlassHighlight: Shape {
    func path(in rect: CGRect) -> Path {
      var path = Path()

      // Define the geometry of the upper 'highlight' shape,
      // covering roughly the top 45% and featuring a characteristic
      // curved bottom reflection line.
      path.move(to: CGPoint(x: rect.minX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.45))

      // Classic Aqua-style specular arc
      path.addQuadCurve(
        to: CGPoint(x: rect.minX, y: rect.maxY * 0.45),
        control: CGPoint(x: rect.midX, y: rect.maxY * 0.6)
      )

      path.closeSubpath()
      return path
    }
  }

  private struct BottomGlassShadow: Shape {
    func path(in rect: CGRect) -> Path {
      var path = Path()

      // Define the geometry of the lower 'shadow' shape, complementary to the top highlight,
      // filling the bottom 55% with a slightly convex top edge.
      path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.45))

      // Complementary convex arc, starting slightly *higher* and curving deeper
      path.addQuadCurve(
        to: CGPoint(x: rect.maxX, y: rect.maxY * 0.45),
        control: CGPoint(x: rect.midX, y: rect.maxY * 0.65)
      )

      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))

      path.closeSubpath()
      return path
    }
  }
}
