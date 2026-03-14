// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

// MARK: - TrackFieldFallbacks

public struct TrackFieldFallbacks: OptionSet, Sendable, Hashable {
  // MARK: Lifecycle

  public init(rawValue: Int) { self.rawValue = rawValue }

  // MARK: Public

  /// Title fell back to filename.
  public static let title = TrackFieldFallbacks(rawValue: 1 << 0)
  /// Artist fell back to composer, album artist, or "Unknown Artist".
  public static let artist = TrackFieldFallbacks(rawValue: 1 << 1)
  /// Album title fell back to track title or "Unknown Album".
  public static let albumTitle = TrackFieldFallbacks(rawValue: 1 << 2)
  /// Album artist fell back to (effective) artist.
  public static let albumArtist = TrackFieldFallbacks(rawValue: 1 << 3)

  public let rawValue: Int
}

// MARK: - Track

public struct Track: Identifiable, Hashable, Sendable {
  // MARK: Lifecycle

  public init(
    id: UUID = UUID(),
    fileURL: URL,
    title: String? = nil,
    artist: String = "Unknown Artist",
    albumTitle: String = "Unknown Album",
    albumArtist: String = "",
    trackNumber: Int = 0,
    discNumber: Int = 0,
    duration: TimeInterval = 0,
    genre: String = "",
    year: Int? = nil,
    fallbackFields: TrackFieldFallbacks = []
  ) {
    self.id = id
    self.fileURL = fileURL
    self.folderPath = fileURL.deletingLastPathComponent().path
    self.title = title ?? fileURL.deletingPathExtension().lastPathComponent
    self.artist = artist
    self.albumTitle = albumTitle
    self.albumArtist = albumArtist.isEmpty ? artist : albumArtist
    self.trackNumber = trackNumber
    self.discNumber = discNumber
    self.duration = duration
    self.genre = genre
    self.year = year
    // Merge caller-provided fallback flags with init-level fallbacks.
    var fb = fallbackFields
    if title == nil { fb.insert(.title) }
    if albumArtist.isEmpty { fb.insert(.albumArtist) }
    self.fallbackFields = fb
  }

  // MARK: Public

  public let id: UUID
  public let fileURL: URL
  /// Pre-computed folder path for efficient sorting (avoids repeated URL operations).
  public let folderPath: String
  public var title: String
  public var artist: String
  public var albumTitle: String
  public var albumArtist: String
  public var trackNumber: Int
  public var discNumber: Int
  public var duration: TimeInterval
  public var genre: String
  public var year: Int?
  public var bookmarkData: Data?
  public var fallbackFields: TrackFieldFallbacks = []
}

extension Array where Element == Track {
  /// 多執行緒就地排序。
  /// - Parameter parallel: 是否啟用多執行緒（預設 true）。數據量 < 10,000 時自動回退單執行緒。
  /// - Returns: 排序後的自身（Fluent interface）
  @discardableResult
  mutating func selfSortByDefault(parallel: Bool = true) async -> Self {
    if !parallel || count < 5000 {
      // 小規模資料：單執行緒更快（避免 Task 開銷）
      self = sorted(by: Self.defaultComparison)
    } else {
      // 大規模資料：平行合併排序
      self = await parallelMergeSort()
    }
    return self
  }

  /// 預設比較器：Artist -> Album -> Disc -> Track -> Title
  private static func defaultComparison(_ lhs: Track, _ rhs: Track) -> Bool {
    (
      lhs.albumArtist, lhs.albumTitle, lhs.discNumber, lhs.trackNumber, lhs.title
    ) < (
      rhs.albumArtist, rhs.albumTitle, rhs.discNumber, rhs.trackNumber, rhs.title
    )
  }

  /// 平行合併排序實現。
  /// 策略：將陣列分為 n 份（n = CPU 核心數），平行排序後用 k-way 合併。
  private func parallelMergeSort() async -> [Track] {
    let processorCount = ProcessInfo.processInfo.processorCount
    let chunkSize = Swift.max(count / processorCount, 1)

    // 如果分片後每片太小，直接單執行緒
    if chunkSize < 2_500 {
      return sorted(by: Self.defaultComparison)
    }

    // 1. 分片
    var chunks: [[Track]] = []
    for i in stride(from: 0, to: count, by: chunkSize) {
      let end = Swift.min(i + chunkSize, count)
      chunks.append(Array(self[i ..< end]))
    }

    // 2. 平行排序每片（使用 TaskGroup 限制平行任務數量）
    let sortedChunks = await withTaskGroup(of: [Track].self) { group in
      for chunk in chunks {
        group.addTask {
          // 每片內部使用高效能單執行緒排序
          chunk.sorted(by: Self.defaultComparison)
        }
      }

      var results: [[Track]] = []
      results.reserveCapacity(chunks.count)
      for await sortedChunk in group {
        results.append(sortedChunk)
      }
      return results
    }

    // 3. 多路合併（迭代式兩兩合併）
    return kWayMerge(sortedChunks)
  }

  /// 迭代式兩兩合併（避免遞歸深度問題）。
  private func kWayMerge(_ chunks: [[Track]]) -> [Track] {
    var current = chunks
    let comparison = Self.defaultComparison

    while current.count > 1 {
      var next: [[Track]] = []
      next.reserveCapacity((current.count + 1) / 2)

      for i in stride(from: 0, to: current.count, by: 2) {
        if i + 1 < current.count {
          next.append(binaryMerge(current[i], current[i + 1], comparison: comparison))
        } else {
          next.append(current[i])
        }
      }
      current = next
    }

    return current.first ?? []
  }

  /// 標準二分合併（已改良記憶體預分配）。
  private func binaryMerge(
    _ left: [Track],
    _ right: [Track],
    comparison: (Track, Track) -> Bool
  )
    -> [Track] {
    var result: [Track] = []
    result.reserveCapacity(left.count + right.count)

    var i = left.startIndex
    var j = right.startIndex

    while i < left.endIndex, j < right.endIndex {
      if comparison(left[i], right[j]) {
        result.append(left[i])
        i = left.index(after: i)
      } else {
        result.append(right[j])
        j = right.index(after: j)
      }
    }

    // 追加剩餘元素
    if i < left.endIndex {
      result.append(contentsOf: left[i...])
    }
    if j < right.endIndex {
      result.append(contentsOf: right[j...])
    }

    return result
  }
}
