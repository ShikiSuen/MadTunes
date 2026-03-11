// (c) 2024 and onwards Pizza Studio (MIT License).
// ====================
// This code is released under the SPDX-License-Identifier: `MIT License`.

// Author: Shiki Suen

import SwiftUI

extension Gradient {
  public static var angularColorGradient: AngularGradient {
    AngularGradient(
      gradient: Gradient(stops: [
        .init(color: Color(hue: 3 / 6, saturation: 1, brightness: 1), location: 0.0 / 6),
        .init(color: Color(hue: 4 / 6, saturation: 1, brightness: 1), location: 1.0 / 6),
        .init(color: Color(hue: 5 / 6, saturation: 1, brightness: 1), location: 2.0 / 6),
        .init(color: Color(hue: 6 / 6, saturation: 1, brightness: 1), location: 3.0 / 6),
        .init(color: Color(hue: 0 / 6, saturation: 1, brightness: 1), location: 4.0 / 6),
        .init(color: Color(hue: 1 / 6, saturation: 1, brightness: 1), location: 5.0 / 6),
        .init(color: Color(hue: 2 / 6, saturation: 1, brightness: 1), location: 1.0),
      ]),
      center: .center
    )
  }

  @ViewBuilder public static var ColorMeshGradient: some View {
    if #available(macOS 15.0, iOS 18.0, *) {
      MeshGradient(
        width: 2,
        height: 2,
        points: [
          SIMD2(0.0, 0.0), // Top-left
          SIMD2(1.0, 0.0), // Top-right
          SIMD2(0.0, 1.0), // Bottom-left
          SIMD2(1.0, 1.0), // Bottom-right
        ],
        colors: [
          .red,
          .blue,
          .green,
          .purple,
        ]
      )
      .opacity(0.3)
      .background {
        Color.primary.colorInvert()
      }
    } else {
      Self.angularColorGradient
        .blur(radius: 8)
        .opacity(0.3)
        .background {
          Color.primary.colorInvert()
        }
    }
  }
}
