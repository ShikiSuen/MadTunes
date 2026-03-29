// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import NaturalLanguage

/// Phase 142: Fixes incorrectly encoded ID3 metadata strings.
///
/// Background: Many legacy MP3 files (especially from Windows XP era) have ID3 tags
/// that were written with local encodings (GBK, Big5, Shift-JIS, etc.) but incorrectly
/// marked as ISO-8859-1 (encoding byte = 0). AVFoundation reads these as ISO-8859-1,
/// resulting in garbled text (mojibake).
///
/// This utility attempts to detect and fix such encoding errors by:
/// 1. Converting the ISO-8859-1 string back to raw bytes
/// 2. Trying various CJK encodings
/// 3. Selecting the encoding that produces the most valid CJK characters
public enum ID3EncodingFixer: Sendable {
  // MARK: Public

  // MARK: - Public API

  /// Attempts to fix encoding issues in an ID3 metadata string.
  /// Returns the corrected string if a better encoding is found, otherwise returns the original.
  public static func fixEncoding(_ string: String) -> String {
    guard needsEncodingFix(string) else { return string }

    let latin1Data = string.data(using: .isoLatin1) ?? Data()
    guard !latin1Data.isEmpty else { return string }

    let originalScore = scoreCandidate(string)
    guard let bestMatch = findBestEncoding(for: latin1Data, minimumScore: originalScore + 20) else {
      return string
    }

    return bestMatch.string
  }

  /// Checks if a string likely has encoding issues (contains high-byte Latin-1 characters).
  public static func needsEncodingFix(_ string: String) -> Bool {
    guard !string.isEmpty else { return false }

    var highByteCount = 0
    var totalNonASCII = 0

    for scalar in string.unicodeScalars {
      let value = scalar.value
      if value > 127 {
        totalNonASCII += 1
        // Latin-1 supplement range (128-255) indicates potential encoding error
        if value >= 128, value <= 255 {
          highByteCount += 1
        }
      }
    }

    // If more than 30% of non-ASCII characters are in Latin-1 range, likely encoding error
    guard totalNonASCII > 0 else { return false }
    let highByteRatio = Double(highByteCount) / Double(totalNonASCII)
    guard highByteRatio > 0.3 else { return false }

    // Legitimate Latin text with a few accents (e.g., "Beyonce", "Björk")
    // should not be treated as mojibake.
    if highByteCount < 3 { return false }
    if isLikelyLegitimateLatinText(string, highByteCount: highByteCount) { return false }

    return true
  }

  // MARK: Private

  private static let cjkEncodings: [(String.Encoding, String)] = {
    var encodings: [(String.Encoding, String)] = []

    // Shift-JIS - Japanese (priority for ambiguous CJK where kana may be absent)
    let shiftJIS = String.Encoding(
      rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.shiftJIS.rawValue)
      )
    )
    encodings.append((shiftJIS, "ShiftJIS"))

    // GB18030 (superset of GBK) - Simplified Chinese
    let gb18030 = String.Encoding(
      rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
      )
    )
    encodings.append((gb18030, "GB18030"))

    // Big5 - Traditional Chinese
    let big5 = String.Encoding(
      rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.big5.rawValue)
      )
    )
    encodings.append((big5, "Big5"))

    // EUC-JP - Japanese
    let eucJP = String.Encoding(
      rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.EUC_JP.rawValue)
      )
    )
    encodings.append((eucJP, "EUC-JP"))

    // ISO-2022-JP - Japanese
    let iso2022JP = String.Encoding(
      rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.ISO_2022_JP.rawValue)
      )
    )
    encodings.append((iso2022JP, "ISO-2022-JP"))

    // EUC-KR - Korean
    let eucKR = String.Encoding(
      rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)
      )
    )
    encodings.append((eucKR, "EUC-KR"))

    // Windows-1251 - Cyrillic
    let win1251 = String.Encoding(
      rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.windowsCyrillic.rawValue)
      )
    )
    encodings.append((win1251, "Windows-1251"))

    // KOI8-R - Russian (Cyrillic)
    let koi8R = String.Encoding(
      rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.KOI8_R.rawValue)
      )
    )
    encodings.append((koi8R, "KOI8-R"))

    return encodings
  }()

  private static func isLikelyLegitimateLatinText(_ string: String, highByteCount: Int) -> Bool {
    var latinLetterCount = 0
    var asciiLetterCount = 0
    var nonLatinLetterCount = 0

    for scalar in string.unicodeScalars {
      guard CharacterSet.letters.contains(scalar) else { continue }

      if isLatinLetterScalar(scalar.value) {
        latinLetterCount += 1
        if scalar.isASCII { asciiLetterCount += 1 }
      } else {
        nonLatinLetterCount += 1
      }
    }

    guard latinLetterCount > 0 else { return false }
    guard nonLatinLetterCount == 0 else { return false }

    // Require enough ASCII baseline to avoid treating mojibaked uppercase runs
    // as legitimate western text.
    guard asciiLetterCount >= 3 else { return false }

    let highByteRatioAmongLatin = Double(highByteCount) / Double(latinLetterCount)
    return highByteRatioAmongLatin < 0.4
  }

  private static func isLatinLetterScalar(_ value: UInt32) -> Bool {
    switch value {
    case 0x0041 ... 0x005A, 0x0061 ... 0x007A,
         0x00C0 ... 0x00D6, 0x00D8 ... 0x00F6, 0x00F8 ... 0x00FF,
         0x0100 ... 0x024F, 0x1E00 ... 0x1EFF:
      return true
    default:
      return false
    }
  }

  private static func scoreCandidate(_ string: String) -> Int {
    let cjkCount = countCJKCharacters(string)
    let kanaCount = countHiraganaKatakana(string)
    let cyrillicCount = countCyrillicCharacters(string)
    let replacementCount = string.filter { $0 == "�" }.count

    var score = cjkCount * 100 + kanaCount * 120 + cyrillicCount * 30

    // reward stronger script signature for truly language-specific content
    if kanaCount > 0 { score += 120 }
    if cyrillicCount > 0 { score += 30 }

    // strongly favor candidates that contain CJK characters in this context,
    // because most ID3 polish/track metadata in this repo is CJK-heavy.
    if cjkCount > 0 {
      score += 1200
    } else if cyrillicCount > 0 {
      score += 200
    }

    // reject invalid UTF-8 replacement characters quickly
    score -= replacementCount * 200

    // discourage pure Latin1 / ISO-8859-1 paths when there are no meaningful CJK/Cyrillic
    let asciiCount = string.filter { $0.isASCII }.count
    if asciiCount > 0, cjkCount + kanaCount + cyrillicCount == 0 {
      score -= asciiCount / 2
    }

    // language model confidence bonus
    score += languageMatchBonus(string)

    return score
  }

  private static func detectedLanguage(of string: String) -> String? {
    let tagger = NLTagger(tagSchemes: [.language])
    tagger.string = string
    let (tag, _) = tagger.tag(at: string.startIndex, unit: .paragraph, scheme: .language)
    return tag?.rawValue
  }

  private static func languageMatchBonus(_ string: String) -> Int {
    guard let language = detectedLanguage(of: string) else { return 0 }

    switch language {
    case "ja", "ja-JP":
      return 20
    case "ko", "ko-KR":
      return 20
    case "zh", "zh-CN", "zh-Hans", "zh-Hant", "zh-HK", "zh-TW":
      return 20
    case "ru", "ru-RU":
      return 20
    default:
      return 0
    }
  }

  private static func findBestEncoding(for data: Data, minimumScore: Int) -> (string: String, score: Int)? {
    var bestResult: (string: String, score: Int, preferenceIndex: Int)?

    for (index, (encoding, _)) in cjkEncodings.enumerated() {
      guard let decoded = String(data: data, encoding: encoding) else { continue }

      // Verify round-trip equivalency if possible.
      let roundTripMatches = decoded.data(using: encoding) == data

      let cjkCount = countCJKCharacters(decoded)
      let kanaCount = countHiraganaKatakana(decoded)
      let cyrillicCount = countCyrillicCharacters(decoded)

      var candidateScore = scoreCandidate(decoded)
      candidateScore += encodingLanguageAlignmentBonus(
        language: detectedLanguage(of: decoded),
        encodingName: cjkEncodings[index].1,
        cjkCount: cjkCount,
        kanaCount: kanaCount,
        cyrillicCount: cyrillicCount
      )
      if roundTripMatches {
        candidateScore += 1_000
      }

      // Skip if no meaningful score.
      guard candidateScore > 0 else { continue }

      if candidateScore >= minimumScore {
        if let best = bestResult {
          if candidateScore > best.score || (candidateScore == best.score && index < best.preferenceIndex) {
            bestResult = (decoded, candidateScore, index)
          }
        } else {
          bestResult = (decoded, candidateScore, index)
        }
      }
    }

    return bestResult.map { ($0.string, $0.score) }
  }

  private static func encodingLanguageAlignmentBonus(
    language: String?,
    encodingName: String,
    cjkCount: Int,
    kanaCount: Int,
    cyrillicCount: Int
  )
    -> Int {
    // High confidence on script match, regardless of NL tagger.
    var bonus = 0

    if cjkCount > 0 {
      switch encodingName {
      case "GB18030": bonus += 250
      case "Big5": bonus += 200
      case "EUC-JP", "ISO-2022-JP", "ShiftJIS": bonus += 50
      default: bonus -= 50
      }
    }

    if kanaCount > 0 {
      if ["ShiftJIS", "EUC-JP", "ISO-2022-JP"].contains(encodingName) {
        bonus += 300
      } else {
        bonus -= 100
      }
    }

    if cyrillicCount > 0 {
      if ["Windows-1251", "KOI8-R"].contains(encodingName) {
        bonus += 250
      } else {
        bonus -= 80
      }
    }

    // Natural language validation if available.
    if let language = language {
      switch language {
      case "ja", "ja-JP":
        if ["ShiftJIS", "EUC-JP", "ISO-2022-JP"].contains(encodingName) {
          bonus += 200
        }
      case "ko", "ko-KR":
        if encodingName == "EUC-KR" { bonus += 200 }
      case "zh", "zh-CN", "zh-Hans":
        if encodingName == "GB18030" { bonus += 200 } else if encodingName == "Big5" { bonus += 100 }
      case "zh-Hant", "zh-HK", "zh-TW":
        if encodingName == "Big5" { bonus += 200 }
      case "ru", "ru-RU":
        if ["Windows-1251", "KOI8-R"].contains(encodingName) {
          bonus += 200
        }
      default:
        break
      }
    }

    return bonus
  }

  private static func countCJKCharacters(_ string: String) -> Int {
    string.filter { char in
      let scalar = char.unicodeScalars.first?.value ?? 0
      // CJK Unified Ideographs
      return (0x4E00 ... 0x9FFF).contains(scalar) ||
        // CJK Unified Ideographs Extension A
        (0x3400 ... 0x4DBF).contains(scalar) ||
        // CJK Unified Ideographs Extension B-F
        (0x20000 ... 0x2CEAF).contains(scalar) ||
        // CJK Compatibility Ideographs
        (0xF900 ... 0xFAFF).contains(scalar)
    }.count
  }

  private static func countCyrillicCharacters(_ string: String) -> Int {
    string.filter { char in
      let scalar = char.unicodeScalars.first?.value ?? 0
      // Cyrillic
      return (0x0400 ... 0x04FF).contains(scalar) ||
        // Cyrillic Supplement
        (0x0500 ... 0x052F).contains(scalar)
    }.count
  }

  private static func countHiraganaKatakana(_ string: String) -> Int {
    string.filter { char in
      let scalar = char.unicodeScalars.first?.value ?? 0
      // Hiragana
      return (0x3040 ... 0x309F).contains(scalar) ||
        // Katakana
        (0x30A0 ... 0x30FF).contains(scalar)
    }.count
  }
}
