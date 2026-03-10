// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - ArtworkView

/// Displays album artwork from raw `Data`, falling back to a music-note placeholder.
struct ArtworkView: View {
  // MARK: Internal

  let data: Data?

  var body: some View {
    Group {
      if let data, let image = Self.makeImage(from: data) {
        ZStack {
          Self.dominantColor(from: data) ?? Color.gray.opacity(0.3)
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
        }
      } else {
        ZStack {
          LinearGradient(
            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          Image(systemName: "music.note")
            .font(.title)
            .foregroundStyle(.secondary)
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  /// Extract the dominant color from image data, avoiding black, white,
  /// and desaturated colors. Falls back through secondary/tertiary candidates.
  /// Dominance is determined by hue bucket frequency.
  static func dominantColor(from data: Data) -> Color? {
    guard let cgImage = CGImage.instantiate(data: data) else { return nil }

    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return nil }

    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width

    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let pixelData = context.data else { return nil }
    let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

    // 36 hue buckets (10° each). Each bucket accumulates total saturation,
    // brightness, and pixel count for averaging.
    let hueBucketCount = 36
    struct BucketAccumulator {
      var count: Int = 0
      var totalH: Double = 0
      var totalS: Double = 0
      var totalB: Double = 0

      var isEmpty: Bool {
        count < 1
      }
    }
    var buckets = [BucketAccumulator](repeating: BucketAccumulator(), count: hueBucketCount)

    let step = max(1, min(width, height) / 40)

    for y in stride(from: 0, to: height, by: step) {
      for x in stride(from: 0, to: width, by: step) {
        let offset = (y * width + x) * bytesPerPixel
        let rf = Double(pixels[offset]) / 255.0
        let gf = Double(pixels[offset + 1]) / 255.0
        let bf = Double(pixels[offset + 2]) / 255.0

        let (h, s, b) = rgbToHSB(rf, gf, bf)

        // Skip near-black, near-white, and very desaturated pixels.
        if b < 0.15 { continue } // too dark
        if b > 0.9, s < 0.1 { continue } // near-white
        if s < 0.08 { continue } // desaturated gray

        let bucketIdx = min(hueBucketCount - 1, Int(h * Double(hueBucketCount)))
        buckets[bucketIdx].count += 1
        buckets[bucketIdx].totalH += h
        buckets[bucketIdx].totalS += s
        buckets[bucketIdx].totalB += b
      }
    }

    // Sort buckets by count descending, try each as a candidate.
    let ranked = buckets.enumerated()
      .filter { !$0.element.isEmpty }
      .sorted { $0.element.count > $1.element.count }

    for (_, bucket) in ranked {
      let n = Double(bucket.count)
      let avgS = bucket.totalS / n
      let avgB = bucket.totalB / n
      let avgH = bucket.totalH / n

      // Reject candidates that still look black/white/gray to the eye.
      if avgB < 0.2 { continue }
      if avgB > 0.85, avgS < 0.12 { continue }
      if avgS < 0.1 { continue }

      return Color(hue: avgH, saturation: avgS, brightness: avgB)
    }

    // Every bucket was rejected — return a muted gray as last resort.
    return Color.gray.opacity(0.3)
  }

  // MARK: Private

  // MARK: - Platform Image Conversion

  private static func makeImage(from data: Data) -> Image? {
    guard let cgImage = CGImage.instantiate(data: data) else { return nil }
    return Image(decorative: cgImage, scale: 1)
  }

  /// Convert RGB (0…1) to HSB (0…1).
  private static func rgbToHSB(
    _ r: Double, _ g: Double, _ b: Double
  )
    -> (h: Double, s: Double, b: Double) {
    let maxC = max(r, g, b)
    let minC = min(r, g, b)
    let delta = maxC - minC

    let brightness = maxC
    let saturation = maxC > 0 ? delta / maxC : 0

    var hue: Double = 0
    if delta > 0 {
      if maxC == r {
        hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
      } else if maxC == g {
        hue = (b - r) / delta + 2
      } else {
        hue = (r - g) / delta + 4
      }
      hue /= 6
      if hue < 0 { hue += 1 }
    }

    return (hue, saturation, brightness)
  }
}
