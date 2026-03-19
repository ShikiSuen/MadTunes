// This implementation is considered as copyleft from public domain.

// Phase 97: RawRepresentable conformances for @AppStorage support.
// RawValue = String (JSON) is required because @AppStorage only supports
// RawRepresentable where RawValue == String or RawValue == Int.

import Foundation

// MARK: - Dictionary + RawRepresentable

extension Dictionary: @retroactive RawRepresentable where Key == String, Value: Codable {
  public init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8) else { return nil }
    self = (try? JSONDecoder().decode([String: Value].self, from: data)) ?? [:]
  }

  public var rawValue: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(self) else { return "{}" }
    return String(data: data, encoding: .utf8) ?? "{}"
  }
}

// MARK: - Array + RawRepresentable

extension Array: @retroactive RawRepresentable where Element: Codable {
  public init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8) else { return nil }
    self = (try? JSONDecoder().decode([Element].self, from: data)) ?? []
  }

  public var rawValue: String {
    guard let data = try? JSONEncoder().encode(self) else { return "[]" }
    return String(data: data, encoding: .utf8) ?? "[]"
  }
}
