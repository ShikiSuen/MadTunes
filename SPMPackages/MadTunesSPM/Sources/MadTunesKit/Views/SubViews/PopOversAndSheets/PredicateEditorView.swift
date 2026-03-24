// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - PredicateEditorView

/// Sheet for editing a dynamic playlist's predicates.
/// Supports nested allOf/anyOf sub-groups for complex hierarchical predicates.
struct PredicateEditorView: View {
  // MARK: Lifecycle

  /// Phase 121: Accept an externally-owned VM so editing state survives iPad WPUI↔desktop switch.
  init(vm: PredicateEditorViewModel) {
    self.vm = vm
  }

  // MARK: Internal

  var body: some View {
    @Bindable var bindableVM = vm

    // 此處以 SafeAreaInset 取代 Toolbar 以完美控制在 AppKit 的 UI 的顯示位置。
    NavigationStack {
      predicatesList(rootNodes: $bindableVM.rootNodes)
        .safeAreaInset(edge: .top, spacing: 0) {
          headerBar(matchMode: $bindableVM.matchMode)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
          footerBar
            .background(.ultraThinMaterial)
        }
    }
    .frame(minWidth: horizontalSizeClass == .compact ? nil : 720, minHeight: 300)
  }

  // MARK: Private

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dismiss) private var dismiss
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var vm: PredicateEditorViewModel

  private var matchingCountText: String {
    if let count = vm.matchingTrackCount() {
      let format = String(localized: "i18n:PredicateEditor.MatchCount.%lld", bundle: #bundle)
      return String.localizedStringWithFormat(format, Int64(count))
    }
    return String(localized: "i18n:PredicateEditor.NoPredicates", bundle: #bundle)
  }

  // MARK: - Footer

  private var footerBar: some View {
    HStack {
      Text(matchingCountText)
        .foregroundStyle(.secondary)
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {
        dismiss()
      }
      .buttonStyle(.bordered)
      Button(String(localized: "i18n:PredicateEditor.Apply", bundle: #bundle)) {
        vm.applyChanges()
        dismiss()
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
  }

  // MARK: - Header

  private func headerBar(matchMode: Binding<PredicateEditorViewModel.MatchMode>) -> some View {
    HStack {
      Text(vm.playlistName)
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
      Picker(
        String(localized: "i18n:PredicateEditor.MatchMode", bundle: #bundle),
        selection: matchMode
      ) {
        Text(String(localized: "i18n:PredicateEditor.MatchAll", bundle: #bundle))
          .tag(PredicateEditorViewModel.MatchMode.all)
        Text(String(localized: "i18n:PredicateEditor.MatchAny", bundle: #bundle))
          .tag(PredicateEditorViewModel.MatchMode.any)
      }
      .pickerStyle(.segmented)
      .fixedSize()
    }
    .padding()
  }

  // MARK: - Predicates List

  private func predicatesList(rootNodes: Binding<[PredicateEditorViewModel.PredicateNode]>) -> some View {
    Form {
      PredicateGroupView(nodes: rootNodes, depth: 0)
    }
    .formStyle(.grouped)
  }
}

// MARK: - PredicateGroupView

/// Phase 121: Card-based recursive group rendering, matching WPUI's visual style.
/// Uses rounded-rect nesting instead of depth-prefix arrows.
private struct PredicateGroupView: View {
  // MARK: Internal

  @Binding var nodes: [PredicateEditorViewModel.PredicateNode]

  let depth: Int

  var body: some View {
    ForEach($nodes) { $node in
      if node.isGroup {
        groupCard(node: $node)
      } else {
        PredicateLeafRowView(predicate: node.leafPredicate) { updated in
          node.leafPredicate = updated
        } onDelete: {
          nodes.removeAll { $0.id == node.id }
        }
      }
    }
    addMenu
  }

  // MARK: Private

  private var addMenu: some View {
    Menu {
      Button {
        nodes.append(
          .leaf(PlaylistCondition(field: .title, comparator: .contains, value: .string("")))
        )
      } label: {
        Label(
          String(localized: "i18n:PredicateEditor.AddPredicate", bundle: #bundle),
          systemImage: "plus.circle"
        )
      }
      Divider()
      Button {
        nodes.append(.group(mode: .all))
      } label: {
        Label(
          String(localized: "i18n:PredicateEditor.AddSubGroup.AllOf", bundle: #bundle),
          systemImage: "folder.badge.plus"
        )
      }
      Button {
        nodes.append(.group(mode: .any))
      } label: {
        Label(
          String(localized: "i18n:PredicateEditor.AddSubGroup.AnyOf", bundle: #bundle),
          systemImage: "folder.badge.plus"
        )
      }
    } label: {
      if OS.isAppKit {
        Label(
          String(localized: "i18n:PredicateEditor.AddPredicate", bundle: #bundle),
          systemImage: "plus.circle"
        )
      } else {
        Label(
          String(localized: "i18n:PredicateEditor.AddPredicate", bundle: #bundle),
          systemImage: "plus.circle"
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
      }
    }
  }

  @ViewBuilder
  private func groupCard(node: Binding<PredicateEditorViewModel.PredicateNode>) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      LabeledContent {
        HStack {
          Picker(
            String(localized: "i18n:PredicateEditor.MatchMode", bundle: #bundle),
            selection: node.groupMode
          ) {
            Text(String(localized: "i18n:PredicateEditor.MatchAll", bundle: #bundle))
              .tag(PredicateEditorViewModel.MatchMode.all)
            Text(String(localized: "i18n:PredicateEditor.MatchAny", bundle: #bundle))
              .tag(PredicateEditorViewModel.MatchMode.any)
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          Button(role: .destructive) {
            nodes.removeAll { $0.id == node.wrappedValue.id }
          } label: {
            Image(systemName: "minus.circle.fill")
              .foregroundStyle(.red)
          }
          .buttonStyle(.plain)
        }
        .fixedSize()
      } label: {
        Text("i18n:PredicateEditor.MatchMode", bundle: #bundle)
          .fontWeight(.medium)
      }
      AnyView(
        PredicateGroupView(nodes: node.children, depth: depth + 1)
      )
    }
    .padding(12)
    .background(Color.primary.opacity(0.04))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
    }
    .padding(.vertical, 2)
  }
}

// MARK: - PredicateLeafRowView

/// A single predicate row: [Field] [Comparator] [Value] [Delete].
private struct PredicateLeafRowView: View {
  // MARK: Lifecycle

  init(
    predicate: PlaylistCondition,
    onChange: @escaping (PlaylistCondition) -> Void,
    onDelete: @escaping () -> Void
  ) {
    _field = State(initialValue: predicate.field)
    _comparator = State(initialValue: predicate.comparator)
    self.onChange = onChange
    self.onDelete = onDelete

    // Initialize value fields from predicate.
    switch predicate.value {
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
    // Phase 121: HStack on AppKit (wide), VStack on non-AppKit (potentially compact iPad).
    // 非 AppKit Target 的 Sheet 的寬度無法自訂、且過窄（尤其是對德語而言），故採 VStack。
    if OS.isAppKit {
      HStack {
        fieldPicker
        comparatorPicker
        valueField
          .frame(maxWidth: .infinity)
        deleteButton
      }
      .padding(.vertical, 4)
    } else {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          fieldPicker
          comparatorPicker
          Spacer()
          deleteButton
        }
        valueField
      }
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

  private var fieldPicker: some View {
    Picker("".description, selection: $field) {
      ForEach(ConditionField.allCases, id: \.self) { currentField in
        Text(currentField.displayName).tag(currentField)
      }
    }
    .labelsHidden()
    .onChange(of: field) { _, newField in
      let validComparators = Comparator.comparators(for: newField.valueKind)
      if !validComparators.contains(comparator) {
        comparator = validComparators.first ?? .contains
      }
      emitChange()
    }
    .fixedSize()
  }

  private var comparatorPicker: some View {
    Picker("".description, selection: $comparator) {
      ForEach(Comparator.comparators(for: field.valueKind), id: \.self) { currentComparator in
        Text(currentComparator.displayName).tag(currentComparator)
      }
    }
    .labelsHidden()
    .onChange(of: comparator) { _, _ in emitChange() }
    .fixedSize()
  }

  private var deleteButton: some View {
    Button(role: .destructive) {
      onDelete()
    } label: {
      Image(systemName: "minus.circle.fill")
        .foregroundStyle(.red)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder private var valueField: some View {
    switch field.valueKind {
    case .string:
      TextField(
        String(localized: "i18n:PredicateEditor.ValuePlaceholder", bundle: #bundle),
        text: $stringValue
      )
      .textFieldStyle(.roundedBorder)
      .labelsHidden()
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
