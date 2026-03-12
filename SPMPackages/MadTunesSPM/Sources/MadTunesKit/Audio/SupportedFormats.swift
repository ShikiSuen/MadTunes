// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import UniformTypeIdentifiers

public enum SupportedFormats {
  /// File extensions supported for audio playback, matching r128x's format list.
  public static let fileExtensions: Set<String> = [
    "mp3", "mp2", "m4a", "aac", "opus",
    "wav", "aif", "ogg", "aiff", "caf",
    "sd2", "ac3", "flac",
  ]

  /// UTTypes for the file importer (audio).
  public static let fileImportTypes: [UTType] = [.audio]

  /// UTType for folder import.
  public static let folderImportTypes: [UTType] = [.folder]

  /// UTType for import feature on macOS AppKit target.
  public static let macImportTypes: [UTType] = fileImportTypes + folderImportTypes

  /// Check whether a given URL has a supported audio file extension.
  public static func isSupported(_ url: URL) -> Bool {
    fileExtensions.contains(url.pathExtension.lowercased())
  }
}
