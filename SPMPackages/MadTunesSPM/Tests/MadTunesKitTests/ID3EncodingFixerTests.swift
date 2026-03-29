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
    let fixed = ID3EncodingFixer.fixEncoding(mojibake)
    #expect(fixed == original)
  }

  @Test("Fixes GBK mojibake with mixed artist name")
  func fixGBKArtist() {
    let original = "知月倾城"
    let mojibake = simulateMojibake(original, realEncoding: gb18030)!
    let fixed = ID3EncodingFixer.fixEncoding(mojibake)
    #expect(fixed == original)
  }

  @Test("Fixes Big5 mojibake (Traditional Chinese)")
  func fixBig5Mojibake() {
    let original = "測試音樂"
    let mojibake = simulateMojibake(original, realEncoding: big5)!
    let fixed = ID3EncodingFixer.fixEncoding(mojibake)
    #expect(fixed == original)
  }

  @Test("Fixes Shift-JIS mojibake (Japanese)")
  func fixShiftJISMojibake() {
    let original = "東京事変"
    let mojibake = simulateMojibake(original, realEncoding: shiftJIS)!
    let fixed = ID3EncodingFixer.fixEncoding(mojibake)
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
}
