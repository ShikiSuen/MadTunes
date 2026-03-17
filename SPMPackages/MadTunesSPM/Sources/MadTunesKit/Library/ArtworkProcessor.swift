// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import CoreGraphics
import Foundation

/// Phase 92: Dedicated actor for album artwork processing.
/// Replaces per-request `Task.detached` with a single long-lived actor,
/// eliminating repeated thread-pool handoff overhead while still keeping
/// heavy image work (CGImage decode → resize → JPEG encode) off the main actor.
actor ArtworkProcessor {
  static let shared = ArtworkProcessor()

  /// Resizes raw artwork data to 512×512 and encodes as JPEG.
  /// Returns original data on failure.
  func process(_ raw: Data) -> Data {
    func resizeCGImage(_ cgImage: CGImage?) -> CGImage? {
      cgImage?.directResized(
        size: CGSize(width: 512, height: 512),
        preserveAspectRatio: true
      )
    }

    var useJPEGHint = false
    let cgImage: CGImage? = {
      let first = resizeCGImage(CGImage.instantiate(data: raw))
      if first != nil { return first }
      print("[ArtworkProcessor] Standard decode failed, retrying with JPEG hint...")
      useJPEGHint = true
      return resizeCGImage(CGImage.instantiate(data: raw, forceJPEG: true))
    }()

    if let resizedData = cgImage?.encodeToFileData(as: .jpeg(quality: 0.85)) {
      print("[ArtworkProcessor] \(useJPEGHint ? "JPEGHint" : "default") decode successful")
      return resizedData
    } else {
      print("[ArtworkProcessor] All decode attempts failed, using original data")
      return raw
    }
  }
}
