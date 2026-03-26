// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPPredicateEditorView

/// WPUI-native predicate editor using card-based metro interactions.
/// Shares the same editor view model with the desktop predicate editor.
struct WPPredicateEditorView: View {
  // MARK: Lifecycle

  /// Phase 121: Accept an externally-owned VM so editing state survives iPad WPUI↔desktop switch.
  init(vm: PredicateEditorViewModel) {
    self.vm = vm
  }

  // MARK: Internal

  var body: some View {
    @Bindable var bindableVM = vm

    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 12) {
          headerCard(matchMode: $bindableVM.matchMode)

          ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
              if !bindableVM.hasAnyPredicates {
                emptyState
              }

              // Keep add menu visible even when there are no predicates yet.
              WPPredicateGroupView(nodes: $bindableVM.rootNodes, depth: 0, accentColor: accentColor)
            }
            .padding(16)
          }

          footerCard
        }
      }
      .navigationTitle(String(localized: "i18n:Sidebar.EditPredicates", bundle: #bundle))
      #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
      #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {
              dismiss()
            }
            .tint(.white)
          }
        }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @Environment(WPPhoneViewModel.self) private var phoneVM

  private var vm: PredicateEditorViewModel

  private var accentColor: Color {
    phoneVM.wpAccentColor.color
  }

  private var matchingCountText: String {
    if let count = vm.matchingTrackCount() {
      let format = String(localized: "i18n:PredicateEditor.MatchCount.%lld", bundle: #bundle)
      return String.localizedStringWithFormat(format, Int64(count))
    }
    return String(localized: "i18n:PredicateEditor.NoPredicates", bundle: #bundle)
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(String(localized: "i18n:PredicateEditor.NoPredicates", bundle: #bundle))
        .font(.headline)
        .foregroundStyle(.white)

      Text(String(localized: "i18n:PredicateEditor.AddPredicate", bundle: #bundle))
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.6))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(Color.white.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var footerCard: some View {
    HStack(spacing: 10) {
      Text(matchingCountText)
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.7))
        .lineLimit(2)

      Spacer()

      Button(String(localized: "i18n:PredicateEditor.Apply", bundle: #bundle)) {
        vm.applyChanges()
        dismiss()
      }
      .font(.headline)
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(accentColor)
      .clipShape(Capsule())
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.white.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .padding(.horizontal, 16)
    .padding(.bottom, 12)
  }

  private func headerCard(matchMode: Binding<PredicateEditorViewModel.MatchMode>) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(verbatim: vm.playlistName)
        .font(.system(size: 23, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)

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
      .tint(accentColor)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(accentColor.opacity(0.5), lineWidth: 1)
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
  }
}

// MARK: - WPPredicateGroupView

private struct WPPredicateGroupView: View {
  // MARK: Internal

  @Binding var nodes: [PredicateEditorViewModel.PredicateNode]

  let depth: Int
  let accentColor: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach($nodes) { $node in
        if node.isGroup {
          groupCard(node: $node)
        } else {
          WPPredicateLeafCard(
            predicate: node.leafPredicate,
            depth: depth,
            accentColor: accentColor
          ) { updated in
            node.leafPredicate = updated
          } onDelete: {
            nodes.removeAll { $0.id == node.id }
          }
        }
      }
      addMenu
    }
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
      HStack(spacing: 8) {
        // depthLabel removed. It's useless on WPUI.
        Image(systemName: "plus.circle.fill")
          .foregroundStyle(accentColor)
        Text(String(localized: "i18n:PredicateEditor.AddPredicate", bundle: #bundle))
          .foregroundStyle(.white)
          .font(.system(size: 15, weight: .semibold))
        Spacer()
        Image(systemName: "ellipsis.circle")
          .foregroundStyle(.white.opacity(0.6))
      }
      .padding(12)
      .background(Color.white.opacity(0.06))
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
  }

  private func groupCard(node: Binding<PredicateEditorViewModel.PredicateNode>) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        // depthLabel removed. It's useless on WPUI.
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
        .tint(accentColor)

        Button(role: .destructive) {
          nodes.removeAll { $0.id == node.wrappedValue.id }
        } label: {
          Image(systemName: "trash")
            .foregroundStyle(.red)
            .padding(6)
        }
      }

      WPPredicateGroupView(nodes: node.children, depth: depth + 1, accentColor: accentColor)
    }
    .padding(12)
    .background(Color.white.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(accentColor.opacity(0.35), lineWidth: 1)
    }
  }
}

// MARK: - WPPredicateLeafCard

private struct WPPredicateLeafCard: View {
  // MARK: Lifecycle

  init(
    predicate: PlaylistCondition,
    depth: Int,
    accentColor: Color,
    onChange: @escaping (PlaylistCondition) -> Void,
    onDelete: @escaping () -> Void
  ) {
    _field = State(initialValue: predicate.field)
    _comparator = State(initialValue: predicate.comparator)
    self.depth = depth
    self.accentColor = accentColor
    self.onChange = onChange
    self.onDelete = onDelete

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
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        // depthLabel removed. It's useless on WPUI.

        Menu {
          ForEach(ConditionField.allCases, id: \.self) { currentField in
            Button {
              field = currentField
              alignComparatorIfNeeded(for: currentField)
              emitChange()
            } label: {
              Text(currentField.displayName)
            }
          }
        } label: {
          capsuleLabel(text: field.displayName)
        }

        Menu {
          ForEach(Comparator.comparators(for: field.valueKind), id: \.self) { currentComparator in
            Button {
              comparator = currentComparator
              emitChange()
            } label: {
              Text(currentComparator.displayName)
            }
          }
        } label: {
          capsuleLabel(text: comparator.displayName)
        }

        Spacer(minLength: 0)

        Button(role: .destructive) {
          onDelete()
        } label: {
          Image(systemName: "minus.circle.fill")
            .foregroundStyle(.red)
        }
      }

      valueField
    }
    .padding(12)
    .background(Color.white.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // MARK: Private

  @State private var field: ConditionField
  @State private var comparator: Comparator
  @State private var stringValue: String = ""
  @State private var integerValue: String = ""
  @State private var doubleValue: String = ""
  @State private var rangeMinValue: String = ""
  @State private var rangeMaxValue: String = ""

  private let depth: Int
  private let accentColor: Color
  private let onChange: (PlaylistCondition) -> Void
  private let onDelete: () -> Void

  @ViewBuilder private var valueField: some View {
    switch field.valueKind {
    case .string:
      TextField(
        String(localized: "i18n:PredicateEditor.ValuePlaceholder", bundle: #bundle),
        text: $stringValue
      )
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(Color.white.opacity(0.12))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .foregroundStyle(.white)
      .autocorrectionDisabled()
      #if !os(macOS)
        .textInputAutocapitalization(.never)
      #endif
        .onChange(of: stringValue) { _, _ in emitChange() }

    case .integer:
      if comparator == .inRange {
        HStack(spacing: 8) {
          numericField(
            placeholder: String(localized: "i18n:Field.Value.Min", bundle: #bundle),
            text: $rangeMinValue
          )
          Text(verbatim: "–")
            .foregroundStyle(.white.opacity(0.7))
          numericField(
            placeholder: String(localized: "i18n:Field.Value.Max", bundle: #bundle),
            text: $rangeMaxValue
          )
        }
      } else {
        numericField(placeholder: "0", text: $integerValue)
      }

    case .double:
      if comparator == .inRange {
        HStack(spacing: 8) {
          numericField(
            placeholder: String(localized: "i18n:Field.Value.Min", bundle: #bundle),
            text: $rangeMinValue
          )
          Text(verbatim: "–")
            .foregroundStyle(.white.opacity(0.7))
          numericField(
            placeholder: String(localized: "i18n:Field.Value.Max", bundle: #bundle),
            text: $rangeMaxValue
          )
        }
      } else {
        numericField(placeholder: "0.0", text: $doubleValue)
      }
    }
  }

  private func capsuleLabel(text: String) -> some View {
    Text(text)
      .lineLimit(1)
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(accentColor.opacity(0.35))
      .clipShape(Capsule())
  }

  private func numericField(placeholder: String, text: Binding<String>) -> some View {
    TextField(placeholder, text: text)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(Color.white.opacity(0.12))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .foregroundStyle(.white)
    #if !os(macOS)
      .keyboardType(.decimalPad)
    #endif
      .onChange(of: text.wrappedValue) { _, _ in emitChange() }
  }

  private func alignComparatorIfNeeded(for newField: ConditionField) {
    let validComparators = Comparator.comparators(for: newField.valueKind)
    if !validComparators.contains(comparator) {
      comparator = validComparators.first ?? .contains
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
