// (c) 2024 and onwards Pizza Studio (MIT License).
// ====================
// This code is released under the SPDX-License-Identifier: `MIT License`.

import Foundation

// MARK: - Duration Formatting

func formatDuration(_ duration: TimeInterval) -> String {
  guard duration.isFinite, duration >= 0 else { return "0:00" }
  let total = Int(duration)
  let hours = total / 3600
  let minutes = (total % 3600) / 60
  let seconds = total % 60
  if hours > 0 {
    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
  }
  return String(format: "%d:%02d", minutes, seconds)
}

// MARK: - Array Chunking

extension Array {
  /// Splits the array into chunks of the specified size.
  /// - Parameter size: The maximum size of each chunk (must be > 0).
  /// - Returns: An array of chunks. Returns empty array if `size` <= 0 or if the original array is empty.
  func chunked(into size: Int) -> [[Element]] {
    // Defensive: guard against invalid size and empty array to avoid runtime issues with stride.
    guard size > 0, !isEmpty else { return [] }
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0 ..< Swift.min($0 + size, count)])
    }
  }
}
