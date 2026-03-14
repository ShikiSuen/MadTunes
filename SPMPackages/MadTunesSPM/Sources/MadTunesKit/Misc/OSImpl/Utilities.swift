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
    var result: Set<String> = []

    let fullwidthSpace = "\u{3000}"
    let wsnl = CharacterSet.whitespacesAndNewlines
    let trimmingSet = wsnl.union(CharacterSet(charactersIn: fullwidthSpace))
    let separatorSet = wsnl.union(CharacterSet(charactersIn: ",，\u{3000}"))

    // 捕捉 ASCII 雙引號
    let quoted = /"([^\"]+)"/

    // 1) 引號內片段
    matches(of: quoted).forEach { matched in
      let captured = String(matched.1)
      let trimmed = captured.trimmingCharacters(in: trimmingSet)
      if !trimmed.isEmpty {
        result.insert(trimmed)
      }
    }

    // 2) 移除 quoted 段落後再拆分
    let withoutQuotes = replacing(quoted, with: " ")
    let parts = withoutQuotes.components(separatedBy: separatorSet)

    for p in parts {
      let token = p.trimmingCharacters(in: trimmingSet)
      if !token.isEmpty {
        result.insert(token)
      }
    }

    return result
  }
}

// MARK: - Search Tokens Helpers

/// 從使用者輸入的搜尋字串產生對應的關鍵詞集合（小寫）。
/// 會呼叫 `asSearchableKeywords` 做分詞並回傳 lowercased 的集合。
public func searchTokens(from text: String) -> Set<String> {
  let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else { return [] }

  return Set(
    trimmed
      .asSearchableKeywords
      .map { $0.lowercased() }
  )
}

/// 對於一組欄位（fields），檢查每一個 token 是否至少被其中一個欄位命中。
/// 命中規則：
/// 1. 先以欄位的 `asSearchableKeywords` 做 **whole-word 比對**（O(1) set lookup）
/// 2. 若找不到，且 token 長度 ≥ 2，回退到子字串比對。
public func tokensAllMatchAcrossFields(_ tokens: Set<String>, fields: [String]) -> Bool {
  guard !tokens.isEmpty else { return true }
  guard !fields.isEmpty else { return false }

  // 預先 tokenize fields（避免重複 tokenization）
  let fieldTokensLower: [Set<String>] = fields.map {
    Set($0.asSearchableKeywords.map { $0.lowercased() })
  }

  for token in tokens {
    var matched = false

    for (idx, field) in fields.enumerated() {
      // 1) whole-token match (O(1))
      if fieldTokensLower[idx].contains(token) {
        matched = true
        break
      }

      // 2) substring fallback（避免單字母噪聲）
      if token.count >= 2,
         field.range(of: token, options: [.caseInsensitive]) != nil {
        matched = true
        break
      }
    }

    if !matched { return false }
  }

  return true
}
