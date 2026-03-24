// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

// MARK: - PlaylistPredicate

/// Phase 117: Hierarchical predicate for dynamic playlist filtering.
/// Recursive structure supporting arbitrary nesting depth.
public indirect enum PlaylistPredicate: Codable, Hashable, Sendable {
  /// Single condition (leaf node).
  case single(PlaylistCondition)
  /// Any child predicate matches (OR logic).
  case anyOf([PlaylistPredicate])
  /// All child predicates must match (AND logic).
  case allOf([PlaylistPredicate])

  // MARK: Public

  /// Evaluate this predicate against a single track.
  public func evaluate(track: Track) -> Bool {
    switch self {
    case let .single(condition):
      return condition.evaluate(track: track)
    case let .anyOf(predicates):
      return predicates.contains { $0.evaluate(track: track) }
    case let .allOf(predicates):
      return predicates.allSatisfy { $0.evaluate(track: track) }
    }
  }

  /// Filter tracks by this predicate.
  public func filter(tracks: [Track]) -> [Track] {
    tracks.filter { evaluate(track: $0) }
  }
}

// MARK: - PlaylistCondition

/// A single comparison condition.
public struct PlaylistCondition: Codable, Hashable, Sendable {
  // MARK: Lifecycle

  public init(field: ConditionField, comparator: Comparator, value: ConditionValue) {
    self.field = field
    self.comparator = comparator
    self.value = value
  }

  // MARK: Public

  public let field: ConditionField
  public let comparator: Comparator
  public let value: ConditionValue

  /// Evaluate this condition against a single track.
  public func evaluate(track: Track) -> Bool {
    switch field {
    case .title: return evaluateString(track.title)
    case .artist: return evaluateString(track.artist)
    case .albumTitle: return evaluateString(track.albumTitle)
    case .albumArtist: return evaluateString(track.albumArtist)
    case .genre: return evaluateString(track.genre)
    case .folderPath: return evaluateString(track.folderPath)
    case .fileExtension: return evaluateString(track.fileExtension)
    case .year: return evaluateOptionalInt(track.year)
    case .trackNumber: return evaluateInt(track.trackNumber)
    case .discNumber: return evaluateInt(track.discNumber)
    case .duration: return evaluateDouble(track.duration)
    }
  }

  // MARK: Private

  private func evaluateString(_ trackValue: String) -> Bool {
    guard case let .string(target) = value else { return false }
    switch comparator {
    case .contains:
      return trackValue.localizedCaseInsensitiveContains(target)
    case .notContains:
      return !trackValue.localizedCaseInsensitiveContains(target)
    case .equals:
      return trackValue.caseInsensitiveCompare(target) == .orderedSame
    case .notEquals:
      return trackValue.caseInsensitiveCompare(target) != .orderedSame
    case .startsWith:
      return trackValue.lowercased().hasPrefix(target.lowercased())
    case .endsWith:
      return trackValue.lowercased().hasSuffix(target.lowercased())
    default:
      return false
    }
  }

  private func evaluateInt(_ trackValue: Int) -> Bool {
    switch (comparator, value) {
    case let (.equals, .integer(v)): return trackValue == v
    case let (.notEquals, .integer(v)): return trackValue != v
    case let (.greaterThan, .integer(v)): return trackValue > v
    case let (.lessThan, .integer(v)): return trackValue < v
    case let (.greaterOrEqual, .integer(v)): return trackValue >= v
    case let (.lessOrEqual, .integer(v)): return trackValue <= v
    case let (.inRange, .range(min, max)): return Double(trackValue) >= min && Double(trackValue) <= max
    default: return false
    }
  }

  private func evaluateOptionalInt(_ trackValue: Int?) -> Bool {
    guard let trackValue else {
      // For nil year: only "notEquals" should match (the year doesn't equal anything).
      if case .notEquals = comparator { return true }
      return false
    }
    return evaluateInt(trackValue)
  }

  private func evaluateDouble(_ trackValue: Double) -> Bool {
    switch (comparator, value) {
    case let (.equals, .double(v)): return trackValue == v
    case let (.notEquals, .double(v)): return trackValue != v
    case let (.greaterThan, .double(v)): return trackValue > v
    case let (.lessThan, .double(v)): return trackValue < v
    case let (.greaterOrEqual, .double(v)): return trackValue >= v
    case let (.lessOrEqual, .double(v)): return trackValue <= v
    case let (.inRange, .range(min, max)): return trackValue >= min && trackValue <= max
    // Also support integer values for duration comparisons.
    case let (.greaterThan, .integer(v)): return trackValue > Double(v)
    case let (.lessThan, .integer(v)): return trackValue < Double(v)
    case let (.greaterOrEqual, .integer(v)): return trackValue >= Double(v)
    case let (.lessOrEqual, .integer(v)): return trackValue <= Double(v)
    default: return false
    }
  }
}

// MARK: - ConditionField

/// Phase 117: Fields available for predicate filtering.
/// Only fields currently present on Track are included.
public enum ConditionField: String, Codable, CaseIterable, Sendable {
  case title
  case artist
  case albumTitle
  case albumArtist
  case genre
  case year
  case trackNumber
  case discNumber
  case duration
  case fileExtension
  case folderPath

  // MARK: Public

  /// The kind of value this field expects.
  public var valueKind: ConditionValueKind {
    switch self {
    case .albumArtist, .albumTitle, .artist, .fileExtension, .folderPath, .genre, .title:
      return .string
    case .discNumber, .trackNumber, .year:
      return .integer
    case .duration:
      return .double
    }
  }
}

// MARK: - ConditionValueKind

/// Classifies what kind of value a field expects, for UI construction.
public enum ConditionValueKind: Sendable {
  case string
  case integer
  case double
}

// MARK: - Comparator

/// Phase 117: Comparison operators for predicate conditions.
public enum Comparator: String, Codable, CaseIterable, Sendable {
  // String comparators
  case contains
  case notContains
  case equals
  case notEquals
  case startsWith
  case endsWith

  // Numeric comparators (also used for strings via equals/notEquals)
  case greaterThan
  case lessThan
  case greaterOrEqual
  case lessOrEqual
  case inRange

  // MARK: Public

  /// Comparators valid for the given value kind.
  public static func comparators(for kind: ConditionValueKind) -> [Comparator] {
    switch kind {
    case .string:
      return [.contains, .notContains, .equals, .notEquals, .startsWith, .endsWith]
    case .double, .integer:
      return [.equals, .notEquals, .greaterThan, .lessThan, .greaterOrEqual, .lessOrEqual, .inRange]
    }
  }
}

// MARK: - ConditionValue

/// Phase 117: Typed value for predicate condition comparisons.
public enum ConditionValue: Codable, Hashable, Sendable {
  case string(String)
  case integer(Int)
  case double(Double)
  case range(min: Double, max: Double)
}
