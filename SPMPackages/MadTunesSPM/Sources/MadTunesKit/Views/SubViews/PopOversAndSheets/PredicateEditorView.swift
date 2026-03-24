// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - PredicateEditorView

/// Phase 117: Sheet for editing a dynamic playlist's predicate conditions.
struct PredicateEditorView: View {
  // MARK: Lifecycle

  init(playlist: Playlist, library: MusicLibraryProviding) {
    self.playlist = playlist
    self.library = library
    // Decode existing predicate or start with empty allOf.
    if !playlist.predicateData.isEmpty,
       let decoded = try? JSONDecoder().decode(PlaylistPredicate.self, from: playlist.predicateData) {
      switch decoded {
      case let .allOf(children):
        _matchMode = State(initialValue: .all)
        _conditions = State(initialValue: children.compactMap(Self.extractCondition))
      case let .anyOf(children):
        _matchMode = State(initialValue: .any)
        _conditions = State(initialValue: children.compactMap(Self.extractCondition))
      case let .single(condition):
        _matchMode = State(initialValue: .all)
        _conditions = State(initialValue: [condition])
      }
    } else {
      _matchMode = State(initialValue: .all)
      _conditions = State(initialValue: [])
    }
  }

  // MARK: Internal

  enum MatchMode: String, CaseIterable {
    case all
    case any
  }

  var body: some View {
    VStack(spacing: 0) {
      headerBar
      Divider()
      conditionsList
      Divider()
      footerBar
    }
    .frame(minWidth: 560, minHeight: 300)
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  @State private var matchMode: MatchMode
  @State private var conditions: [PlaylistCondition]

  private var playlist: Playlist
  private var library: MusicLibraryProviding

  private var matchingCountText: String {
    let predicate = buildPredicate()
    if let predicate {
      let count = predicate.filter(tracks: library.tracks).count
      let format = String(localized: "i18n:PredicateEditor.MatchCount.%lld", bundle: #bundle)
      return String.localizedStringWithFormat(format, Int64(count))
    }
    return String(localized: "i18n:PredicateEditor.NoConditions", bundle: #bundle)
  }

  // MARK: - Header

  private var headerBar: some View {
    HStack {
      Text(playlist.name)
        .font(.headline)
      Spacer()
      Picker(
        String(localized: "i18n:PredicateEditor.MatchMode", bundle: #bundle),
        selection: $matchMode
      ) {
        Text(String(localized: "i18n:PredicateEditor.MatchAll", bundle: #bundle))
          .tag(MatchMode.all)
        Text(String(localized: "i18n:PredicateEditor.MatchAny", bundle: #bundle))
          .tag(MatchMode.any)
      }
      .pickerStyle(.segmented)
      .fixedSize()
    }
    .padding()
  }

  // MARK: - Conditions List

  private var conditionsList: some View {
    List {
      ForEach(conditions.indices, id: \.self) { index in
        ConditionRowView(condition: conditions[index]) { updated in
          conditions[index] = updated
        } onDelete: {
          conditions.remove(at: index)
        }
      }
      Button {
        conditions.append(
          PlaylistCondition(field: .title, comparator: .contains, value: .string(""))
        )
      } label: {
        Label(
          String(localized: "i18n:PredicateEditor.AddCondition", bundle: #bundle),
          systemImage: "plus.circle"
        )
      }
    }
    .listStyle(.plain)
  }

  // MARK: - Footer

  private var footerBar: some View {
    HStack {
      Text(matchingCountText)
        .foregroundStyle(.secondary)
        .font(.callout)
      Spacer()
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {
        dismiss()
      }
      Button(String(localized: "i18n:PredicateEditor.Apply", bundle: #bundle)) {
        applyAndDismiss()
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
  }

  private static func extractCondition(_ predicate: PlaylistPredicate) -> PlaylistCondition? {
    if case let .single(condition) = predicate { return condition }
    return nil
  }

  // MARK: - Build & Apply

  private func buildPredicate() -> PlaylistPredicate? {
    guard !conditions.isEmpty else { return nil }
    let children = conditions.map { PlaylistPredicate.single($0) }
    switch matchMode {
    case .all: return .allOf(children)
    case .any: return .anyOf(children)
    }
  }

  private func applyAndDismiss() {
    let data: Data
    if let predicate = buildPredicate() {
      data = (try? JSONEncoder().encode(predicate)) ?? Data()
    } else {
      data = Data()
    }
    library.updatePredicateData(playlistID: playlist.id, data: data)
    dismiss()
  }
}

// MARK: - ConditionRowView

/// A single condition row: [Field] [Comparator] [Value] [Delete].
private struct ConditionRowView: View {
  // MARK: Lifecycle

  init(
    condition: PlaylistCondition,
    onChange: @escaping (PlaylistCondition) -> Void,
    onDelete: @escaping () -> Void
  ) {
    _field = State(initialValue: condition.field)
    _comparator = State(initialValue: condition.comparator)
    self.onChange = onChange
    self.onDelete = onDelete
    // Initialize value fields from condition.
    switch condition.value {
    case let .string(s): _stringValue = State(initialValue: s)
    case let .integer(i): _integerValue = State(initialValue: String(i))
    case let .double(d): _doubleValue = State(initialValue: String(d))
    case let .range(min, max):
      _rangeMinValue = State(initialValue: String(min))
      _rangeMaxValue = State(initialValue: String(max))
    }
  }

  // MARK: Internal

  var body: some View {
    HStack {
      Picker("".description, selection: $field) {
        ForEach(ConditionField.allCases, id: \.self) { f in
          Text(f.displayName).tag(f)
        }
      }
      .frame(width: 130)
      .onChange(of: field) { _, newField in
        // Reset comparator to first valid one when field changes.
        let validComparators = Comparator.comparators(for: newField.valueKind)
        if !validComparators.contains(comparator) {
          comparator = validComparators.first ?? .contains
        }
        emitChange()
      }

      Picker("".description, selection: $comparator) {
        ForEach(Comparator.comparators(for: field.valueKind), id: \.self) { c in
          Text(c.displayName).tag(c)
        }
      }
      .frame(width: 130)
      .onChange(of: comparator) { _, _ in emitChange() }

      valueField
        .frame(minWidth: 120)

      Button(role: .destructive) {
        onDelete()
      } label: {
        Image(systemName: "minus.circle.fill")
          .foregroundStyle(.red)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: Private

  @State private var field: ConditionField
  @State private var comparator: Comparator
  @State private var stringValue: String = ""
  @State private var integerValue: String = ""
  @State private var doubleValue: String = ""
  @State private var rangeMinValue: String = ""
  @State private var rangeMaxValue: String = ""

  private let onChange: (PlaylistCondition) -> Void
  private let onDelete: () -> Void

  @ViewBuilder private var valueField: some View {
    switch field.valueKind {
    case .string:
      TextField(
        String(localized: "i18n:PredicateEditor.ValuePlaceholder", bundle: #bundle),
        text: $stringValue
      )
      .textFieldStyle(.roundedBorder)
      .onChange(of: stringValue) { _, _ in emitChange() }
    case .integer:
      if comparator == .inRange {
        HStack {
          TextField(String(localized: "i18n:Field.Value.Min", bundle: #bundle), text: $rangeMinValue)
            .textFieldStyle(.roundedBorder)
            .onChange(of: rangeMinValue) { _, _ in emitChange() }
          Text(verbatim: "–")
          TextField(String(localized: "i18n:Field.Value.Max", bundle: #bundle), text: $rangeMaxValue)
            .textFieldStyle(.roundedBorder)
            .onChange(of: rangeMaxValue) { _, _ in emitChange() }
        }
      } else {
        TextField("0".description, text: $integerValue)
          .textFieldStyle(.roundedBorder)
          .onChange(of: integerValue) { _, _ in emitChange() }
      }
    case .double:
      if comparator == .inRange {
        HStack {
          TextField(String(localized: "i18n:Field.Value.Min", bundle: #bundle), text: $rangeMinValue)
            .textFieldStyle(.roundedBorder)
            .onChange(of: rangeMinValue) { _, _ in emitChange() }
          Text(verbatim: "–")
          TextField(String(localized: "i18n:Field.Value.Max", bundle: #bundle), text: $rangeMaxValue)
            .textFieldStyle(.roundedBorder)
            .onChange(of: rangeMaxValue) { _, _ in emitChange() }
        }
      } else {
        TextField("0.0".description, text: $doubleValue)
          .textFieldStyle(.roundedBorder)
          .onChange(of: doubleValue) { _, _ in emitChange() }
      }
    }
  }

  private func emitChange() {
    let value: ConditionValue
    switch field.valueKind {
    case .string:
      value = .string(stringValue)
    case .integer:
      if comparator == .inRange {
        let min = Double(rangeMinValue) ?? 0
        let max = Double(rangeMaxValue) ?? 0
        value = .range(min: min, max: max)
      } else {
        value = .integer(Int(integerValue) ?? 0)
      }
    case .double:
      if comparator == .inRange {
        let min = Double(rangeMinValue) ?? 0
        let max = Double(rangeMaxValue) ?? 0
        value = .range(min: min, max: max)
      } else {
        value = .double(Double(doubleValue) ?? 0)
      }
    }
    onChange(PlaylistCondition(field: field, comparator: comparator, value: value))
  }
}

// MARK: - Display Names

extension ConditionField {
  var displayName: String {
    switch self {
    case .title: String(localized: "i18n:PredicateEditor.Field.Title", bundle: #bundle)
    case .artist: String(localized: "i18n:PredicateEditor.Field.Artist", bundle: #bundle)
    case .albumTitle: String(localized: "i18n:PredicateEditor.Field.AlbumTitle", bundle: #bundle)
    case .albumArtist: String(localized: "i18n:PredicateEditor.Field.AlbumArtist", bundle: #bundle)
    case .genre: String(localized: "i18n:PredicateEditor.Field.Genre", bundle: #bundle)
    case .year: String(localized: "i18n:PredicateEditor.Field.Year", bundle: #bundle)
    case .trackNumber: String(localized: "i18n:PredicateEditor.Field.TrackNumber", bundle: #bundle)
    case .discNumber: String(localized: "i18n:PredicateEditor.Field.DiscNumber", bundle: #bundle)
    case .duration: String(localized: "i18n:PredicateEditor.Field.Duration", bundle: #bundle)
    case .fileExtension: String(localized: "i18n:PredicateEditor.Field.FileExtension", bundle: #bundle)
    case .folderPath: String(localized: "i18n:PredicateEditor.Field.FolderPath", bundle: #bundle)
    }
  }
}

extension Comparator {
  var displayName: String {
    switch self {
    case .contains: String(localized: "i18n:PredicateEditor.Comp.Contains", bundle: #bundle)
    case .notContains: String(localized: "i18n:PredicateEditor.Comp.NotContains", bundle: #bundle)
    case .equals: String(localized: "i18n:PredicateEditor.Comp.Equals", bundle: #bundle)
    case .notEquals: String(localized: "i18n:PredicateEditor.Comp.NotEquals", bundle: #bundle)
    case .startsWith: String(localized: "i18n:PredicateEditor.Comp.StartsWith", bundle: #bundle)
    case .endsWith: String(localized: "i18n:PredicateEditor.Comp.EndsWith", bundle: #bundle)
    case .greaterThan: String(localized: "i18n:PredicateEditor.Comp.GreaterThan", bundle: #bundle)
    case .lessThan: String(localized: "i18n:PredicateEditor.Comp.LessThan", bundle: #bundle)
    case .greaterOrEqual: String(localized: "i18n:PredicateEditor.Comp.GreaterOrEqual", bundle: #bundle)
    case .lessOrEqual: String(localized: "i18n:PredicateEditor.Comp.LessOrEqual", bundle: #bundle)
    case .inRange: String(localized: "i18n:PredicateEditor.Comp.InRange", bundle: #bundle)
    }
  }
}
