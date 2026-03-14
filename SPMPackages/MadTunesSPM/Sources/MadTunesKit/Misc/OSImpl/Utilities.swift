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

// MARK: - Searchable Keyword Tokenizer

extension String {
  /// 將 this 按照如下規則拆分：
  /// 1. 如果被英文 ASCII 引號對 `""` 括住的話，則被括住的詞拆掉首尾空格之後 會是一個關鍵詞單元，插入至 `result`。
  /// 2. 剩下的詞，用 全形、半形、tab、ASCII-COMMA 分割開之後，塞入 `result`。
  /// 3. 返回 result。
  public var asSearchableKeywords: Set<String> {
    var result: Set<String> = [] // <- 關鍵詞單元集合。

    let fullwidthSpace = "\u{3000}"
    let wsnl = CharacterSet.whitespacesAndNewlines
    let trimmingSet = wsnl.union(CharacterSet(charactersIn: fullwidthSpace))
    let separatorSet = wsnl.union(CharacterSet(charactersIn: ",，\u{3000}"))

    // 使用 Swift 6.2 的內建 Regex literal，捕捉被 ASCII 雙引號包住的群組
    let quoted = /"([^\"]+)"/

    // 1) 擷取所有引號內的片段，trim 後加入結果
    matches(of: quoted).forEach { matched in
      let captured = String(matched.1)
      let trimmed = captured.trimmingCharacters(in: trimmingSet)
      if !trimmed.isEmpty { result.insert(trimmed) }
    }

    // 2) 將所有被引號包住的段落以單一空白取代，對剩餘字串再以分隔集合拆分
    let withoutQuotes = replacing(quoted, with: " ")
    let parts = withoutQuotes.components(separatedBy: separatorSet)
    parts.forEach { p in
      let token = p.trimmingCharacters(in: trimmingSet)
      if !token.isEmpty { result.insert(token) }
    }

    return result
  }
}
