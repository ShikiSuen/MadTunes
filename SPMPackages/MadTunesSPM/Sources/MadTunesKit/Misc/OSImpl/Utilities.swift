// (c) 2024 and onwards Pizza Studio (MIT License).
// ====================
// This code is released under the SPDX-License-Identifier: `MIT License`.

import CryptoKit
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

// MARK: - String to MD5

extension String {
  /// - returns: the String, as an MD5 hash.
  public var md5: String {
    Insecure.MD5.hash(data: Data(utf8)).map {
      String(format: "%02hhx", $0)
    }.joined()
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

// MARK: - UUID Impl.

extension UUID {
  /// Converts an MD5 hash string into a UUID.
  /// - Parameter md5: A 32-character hexadecimal MD5 hash string.
  /// - Throws: An error if the MD5 string is invalid.
  /// - Returns: A UUID generated from the MD5 hash.
  public static func fromMD5(_ md5: String) throws -> UUID {
    // Ensure the MD5 string is valid (32 characters, hexadecimal)
    guard md5.count == 32, md5.range(of: "^[a-fA-F0-9]{32}$", options: .regularExpression) != nil else {
      throw NSError(domain: "InvalidMD5", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid MD5 string."])
    }

    // Convert the MD5 string into raw bytes
    var bytes = [UInt8]()
    var index = md5.startIndex
    for _ in 0 ..< 16 {
      let nextIndex = md5.index(index, offsetBy: 2)
      if let byte = UInt8(md5[index ..< nextIndex], radix: 16) {
        bytes.append(byte)
      }
      index = nextIndex
    }

    // Convert the raw bytes into a UUID
    let uuid = UUID(uuid: (
      bytes[0],
      bytes[1],
      bytes[2],
      bytes[3],
      bytes[4],
      bytes[5],
      bytes[6],
      bytes[7],
      bytes[8],
      bytes[9],
      bytes[10],
      bytes[11],
      bytes[12],
      bytes[13],
      bytes[14],
      bytes[15]
    ))
    return uuid
  }
}

// MARK: - Collection Extensions.

extension Collection {
  public func chunked(into size: Int) -> [[Self.Element]] where Self.Index == Int {
    stride(from: 0, to: count, by: size).map {
      Array(self[$0 ..< Swift.min($0 + size, self.count)])
    }
  }

  public func indicesMeeting(condition: (Element) throws -> Bool) rethrows -> [Index]? {
    let indices = try indices.filter { try condition(self[$0]) }
    return indices.isEmpty ? nil : indices
  }
}

// MARK: - Debug Message Printer

extension String {
  public static func printDebug(
    _ items: Any..., separator: String = " ", terminator: String = "\n"
  ) {
    #if DEBUG
    print(items, separator: separator, terminator: terminator)
    #endif
  }

  public static func printNSLog4Debug(
    _ format: String,
    _ args: any CVarArg...
  ) {
    #if DEBUG
    NSLog(format, args)
    #endif
  }
}

// MARK: - Ask Bundle to tell App Build Number.

extension Bundle {
  public static func getAppVersionAndBuild() throws -> (version: String, build: String) {
    guard let infoDictionary = Bundle.main.infoDictionary else {
      throw NSError(
        domain: "AppInfoError",
        code: 213,
        userInfo: [NSLocalizedDescriptionKey: "Failed to get the app's Info.plist."]
      )
    }

    guard let version = infoDictionary["CFBundleShortVersionString"] as? String,
          let build = infoDictionary["CFBundleVersion"] as? String else {
      throw NSError(
        domain: "AppInfoError",
        code: 233,
        userInfo: [NSLocalizedDescriptionKey: "Version or build number is missing."]
      )
    }

    return (version, build)
  }
}
