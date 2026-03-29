// (c) 2026 and onwards Shiki Suen (AGPL-3.0-or-later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
@testable import MadTunesKit
import Testing

// MARK: - Encoding helpers

private let gb18030: String.Encoding = .init(
  rawValue: CFStringConvertEncodingToNSStringEncoding(
    CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
  )
)

private let big5: String.Encoding = .init(
  rawValue: CFStringConvertEncodingToNSStringEncoding(
    CFStringEncoding(CFStringEncodings.big5.rawValue)
  )
)

private let shiftJIS: String.Encoding = .init(
  rawValue: CFStringConvertEncodingToNSStringEncoding(
    CFStringEncoding(CFStringEncodings.shiftJIS.rawValue)
  )
)

/// Simulates AVFoundation's mojibake: encode `text` with `realEncoding`, then misread as ISO-8859-1.
private func simulateMojibake(_ text: String, realEncoding: String.Encoding) -> String? {
  guard let data = text.data(using: realEncoding) else { return nil }
  return String(data: data, encoding: .isoLatin1)
}

// MARK: - ID3EncodingFixerTests

@Suite("ID3EncodingFixer")
struct ID3EncodingFixerTests {
  // MARK: - needsEncodingFix

  @Test("Empty string does not need fix")
  func emptyString() {
    #expect(!ID3EncodingFixer.needsEncodingFix(""))
  }

  @Test("Pure ASCII does not need fix")
  func pureASCII() {
    #expect(!ID3EncodingFixer.needsEncodingFix("Hello World 123"))
  }

  @Test("Valid UTF-8 CJK does not need fix")
  func validUTF8CJK() {
    #expect(!ID3EncodingFixer.needsEncodingFix("山川挽歌"))
    #expect(!ID3EncodingFixer.needsEncodingFix("こんにちは"))
    #expect(!ID3EncodingFixer.needsEncodingFix("안녕하세요"))
  }

  @Test("Valid Latin text with accents does not need fix")
  func validLatinAccents() {
    #expect(!ID3EncodingFixer.needsEncodingFix("Beyoncé"))
    #expect(!ID3EncodingFixer.needsEncodingFix("Björk Guðmundsdóttir"))
  }

  @Test("GBK-as-Latin1 mojibake is detected")
  func gbkMojibakeDetected() {
    let mojibake = simulateMojibake("山川挽歌", realEncoding: gb18030)!
    #expect(ID3EncodingFixer.needsEncodingFix(mojibake))
  }

  @Test("Big5-as-Latin1 mojibake is detected")
  func big5MojibakeDetected() {
    let mojibake = simulateMojibake("測試音樂", realEncoding: big5)!
    #expect(ID3EncodingFixer.needsEncodingFix(mojibake))
  }

  @Test("ShiftJIS-as-Latin1 mojibake is detected")
  func shiftJISMojibakeDetected() {
    let mojibake = simulateMojibake("東京事変", realEncoding: shiftJIS)!
    #expect(ID3EncodingFixer.needsEncodingFix(mojibake))
  }

  // MARK: - fixEncoding

  @Test("Fixes GBK mojibake (Simplified Chinese)")
  func fixGBKMojibake() {
    let original = "山川挽歌"
    let mojibake = simulateMojibake(original, realEncoding: gb18030)!
    // Phase 143: use explicit Simplified Chinese preferred language for GBK test.
    let fixed = ID3EncodingFixer.fixEncoding(mojibake, preferredLanguages: ["zh-Hans"])
    #expect(fixed == original)
  }

  @Test("Fixes GBK mojibake with mixed artist name")
  func fixGBKArtist() {
    let original = "知月倾城"
    let mojibake = simulateMojibake(original, realEncoding: gb18030)!
    let fixed = ID3EncodingFixer.fixEncoding(mojibake, preferredLanguages: ["zh-Hans"])
    #expect(fixed == original)
  }

  @Test("Fixes Big5 mojibake (Traditional Chinese)")
  func fixBig5Mojibake() {
    let original = "測試音樂"
    let mojibake = simulateMojibake(original, realEncoding: big5)!
    // Phase 143: use explicit Traditional Chinese preferred language for Big5 test.
    let fixed = ID3EncodingFixer.fixEncoding(mojibake, preferredLanguages: ["zh-Hant"])
    #expect(fixed == original)
  }

  @Test("Fixes Shift-JIS mojibake (Japanese)")
  func fixShiftJISMojibake() {
    let original = "東京事変"
    let mojibake = simulateMojibake(original, realEncoding: shiftJIS)!
    // Phase 143: use explicit Japanese preferred language for Shift-JIS test.
    let fixed = ID3EncodingFixer.fixEncoding(mojibake, preferredLanguages: ["ja"])
    #expect(fixed == original)
  }

  @Test("Returns original for pure ASCII")
  func fixEncodingPassthroughASCII() {
    let ascii = "Track 01 - Hello"
    #expect(ID3EncodingFixer.fixEncoding(ascii) == ascii)
  }

  @Test("Returns original for valid UTF-8 CJK")
  func fixEncodingPassthroughUTF8() {
    let valid = "月朔九天"
    #expect(ID3EncodingFixer.fixEncoding(valid) == valid)
  }

  @Test("Returns original for valid Latin text with accents")
  func fixEncodingPassthroughLatinAccents() {
    let valid = "Björk Guðmundsdóttir"
    #expect(ID3EncodingFixer.fixEncoding(valid) == valid)
  }

  @Test("Returns original for empty string")
  func fixEncodingEmptyString() {
    #expect(ID3EncodingFixer.fixEncoding("") == "")
  }

  // MARK: - Phase 143: Locale-aware encoding preference (preferredLanguages)

  @Test("Each preferred language resolves its own encoding's mojibake correctly")
  func localeMatchingEncoding() {
    // GBK → zh-Hans
    let gbkOriginal = "山川挽歌"
    let gbkMojibake = simulateMojibake(gbkOriginal, realEncoding: gb18030)!
    #expect(
      ID3EncodingFixer.fixEncoding(gbkMojibake, preferredLanguages: ["zh-Hans"]) == gbkOriginal
    )

    // Big5 → zh-Hant
    let big5Original = "測試音樂"
    let big5Mojibake = simulateMojibake(big5Original, realEncoding: big5)!
    #expect(
      ID3EncodingFixer.fixEncoding(big5Mojibake, preferredLanguages: ["zh-Hant"]) == big5Original
    )

    // ShiftJIS → ja
    let sjisOriginal = "東京事変"
    let sjisMojibake = simulateMojibake(sjisOriginal, realEncoding: shiftJIS)!
    #expect(
      ID3EncodingFixer.fixEncoding(sjisMojibake, preferredLanguages: ["ja"]) == sjisOriginal
    )
  }

  @Test("Hant-primary with Hans-secondary resolves GBK mojibake via fallback")
  func hantPrimaryHansSecondary() {
    // Simulates a user like zh-Hant-CN, zh-Hans-CN — primary is Big5-preferred,
    // but secondary covers GB18030 so GBK mojibake should still resolve.
    let original = "山川挽歌"
    let mojibake = simulateMojibake(original, realEncoding: gb18030)!
    let fixed = ID3EncodingFixer.fixEncoding(
      mojibake, preferredLanguages: ["zh-Hant-CN", "zh-Hans-CN", "ja-CN", "en-CN"]
    )
    #expect(fixed == original)
  }

  @Test("Neutral locale (en_US only) resolves mojibake using evidence-based scoring")
  func neutralLocaleResolution() {
    let original = "知月倾城"
    let mojibake = simulateMojibake(original, realEncoding: gb18030)!
    let fixed = ID3EncodingFixer.fixEncoding(mojibake, preferredLanguages: ["en"])
    // Should produce CJK text, not the original mojibake.
    #expect(fixed != mojibake)
    #expect(ID3EncodingFixer.countCJKCharacters(fixed) > 0)
  }

  @Test("Preferred encoding families from preferredLanguages")
  func encodingFamiliesDetection() {
    let families = ID3EncodingFixer.preferredEncodingFamilies(
      from: ["zh-Hant-CN", "zh-Hans-CN", "ja-CN", "en-CN"]
    )
    #expect(families.count == 3) // traditionalChinese, simplifiedChinese, japanese
    #expect(families[0].0 == .traditionalChinese)
    #expect(families[1].0 == .simplifiedChinese)
    #expect(families[2].0 == .japanese)
    // Sibling Chinese families are unified to the max bonus (200).
    #expect(families[0].1 == 200)
    #expect(families[1].1 == 200)
    #expect(families[2].1 == 60)
  }
}
