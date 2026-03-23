// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - ColumnBrowserView

/// A three-column filter popover (Genre / Artist / Album) modelled after
/// iTunes' Column Browser but using a modern popover interaction with native Tables.
/// Each column supports multiple selection; selecting "All" clears the column.
struct ColumnBrowserView: View {
  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  static let allOptionTag = "__all__"

  var body: some View {
    VStack(spacing: 0) {
      // Header with controls
      HStack(alignment: .bottom) {
        Text(String(localized: "i18n:ColumnBrowser.Title", bundle: #bundle))
          .font(.headline)
        Spacer()
        if vm.isColumnBrowserFiltering {
          Button(role: .destructive) {
            vm.resetColumnBrowserFilters()
          } label: {
            Text(String(localized: "i18n:ColumnBrowser.ClearAll", bundle: #bundle))
              .font(.caption)
              .foregroundStyle(.primary)
          }
          .tint(.red)
          .controlSize(.mini)
        }
      }
      .padding(.horizontal, 20)
      .frame(height: 28)
      let view1 = filterColumnTable(
        title: String(localized: "i18n:ColumnBrowser.Genres", bundle: #bundle),
        allLabel: String(localized: "i18n:ColumnBrowser.AllGenres", bundle: #bundle),
        items: vm.columnBrowserGenres,
        selection: $vm.columnBrowserSelectedGenres,
        onSelectionChange: {
          // Cascade: if genre selection changed, update available album and song artists + albums
          vm.columnBrowserSelectedAlbumArtists.formIntersection(Set(vm.columnBrowserAlbumArtists))
          vm.columnBrowserSelectedSongArtists.formIntersection(Set(vm.columnBrowserSongArtists))
          vm.columnBrowserSelectedAlbumTitles.formIntersection(Set(vm.columnBrowserAlbumTitles))
        }
      )
      let view2 = filterColumnTable(
        title: String(localized: "i18n:ColumnBrowser.AlbumArtists", bundle: #bundle),
        allLabel: String(localized: "i18n:ColumnBrowser.AllAlbumArtists", bundle: #bundle),
        items: vm.columnBrowserAlbumArtists,
        selection: $vm.columnBrowserSelectedAlbumArtists,
        onSelectionChange: {
          // Cascade: if album‑artist selection changed, update song artists and albums
          vm.columnBrowserSelectedSongArtists.formIntersection(Set(vm.columnBrowserSongArtists))
          vm.columnBrowserSelectedAlbumTitles.formIntersection(Set(vm.columnBrowserAlbumTitles))
        }
      )
      let view3 = filterColumnTable(
        title: String(localized: "i18n:ColumnBrowser.SongArtists", bundle: #bundle),
        allLabel: String(localized: "i18n:ColumnBrowser.AllSongArtists", bundle: #bundle),
        items: vm.columnBrowserSongArtists,
        selection: $vm.columnBrowserSelectedSongArtists,
        onSelectionChange: {
          // Cascade: if song‑artist selection changed, update album artists & titles
          vm.columnBrowserSelectedAlbumArtists.formIntersection(Set(vm.columnBrowserAlbumArtists))
          vm.columnBrowserSelectedAlbumTitles.formIntersection(Set(vm.columnBrowserAlbumTitles))
        }
      )
      let view4 = filterColumnTable(
        title: String(localized: "i18n:ColumnBrowser.Albums", bundle: #bundle),
        allLabel: String(localized: "i18n:ColumnBrowser.AllAlbums", bundle: #bundle),
        items: vm.columnBrowserAlbumTitles,
        selection: $vm.columnBrowserSelectedAlbumTitles,
        onSelectionChange: {}
      )

      if OS.type == .macOS {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
          GridRow {
            view1
            view2
            view3
            view4
          }
        }
      } else {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
          GridRow {
            view2
            view3
          }
          GridRow {
            view1
            view4
          }
        }
      }
    }
    .fixedSize()
  }

  // MARK: Private

  @State private var vm: MadTunesViewModel = .shared
  @Environment(\.colorScheme) private var colorScheme

  #if !canImport(AppKit) || targetEnvironment(macCatalyst)
  /// Tracks the last non-shift-clicked item per column (keyed by allLabel) for Shift+Click range selection.
  @State private var columnAnchors: [String: String] = [:]
  #endif

  // MARK: - Filter column (platform-adaptive)

  @ViewBuilder
  private func filterColumnTable(
    title: String,
    allLabel: String,
    items: [String],
    selection: Binding<Set<String>>,
    onSelectionChange: @escaping () -> Void
  )
    -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 4) {
        Text(verbatim: title)
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)
        #if !canImport(AppKit) || targetEnvironment(macCatalyst)
        Spacer(minLength: 0)
        // Phase 73: Play button in column header (replaces double-tap on rows).
        Button {
          vm.playFilteredTracks()
        } label: {
          Image(systemName: "play.fill")
            .font(.caption2)
        }
        .buttonStyle(.borderedProminent)
        #endif
      }
      .padding(.horizontal, 8)
      .padding(.vertical, OS.type == .macOS ? 6 : 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        Rectangle()
          .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
      }
      #if canImport(AppKit) && !targetEnvironment(macCatalyst)
      filterColumnNativeTable(
        title: title, allLabel: allLabel, items: items,
        selection: selection, onSelectionChange: onSelectionChange
      )
      #else
      // Phase 72/73: Custom button-based list for UIKit targets.
      filterColumnCustomList(
        allLabel: allLabel, items: items,
        selection: selection, onSelectionChange: onSelectionChange
      )
      #endif
    }
  }

  // MARK: - AppKit: Native Table

  #if canImport(AppKit) && !targetEnvironment(macCatalyst)
  @ViewBuilder
  private func filterColumnNativeTable(
    title: String,
    allLabel: String,
    items: [String],
    selection: Binding<Set<String>>,
    onSelectionChange: @escaping () -> Void
  )
    -> some View {
    Table(tableItems(allLabel: allLabel, items: items), selection: selection) {
      TableColumn(title) { item in
        Text(item.label)
          .font(.caption)
          .lineLimit(1)
          .truncationMode(.tail)
          .listRowBackground(Color.clear)
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .frame(
      width: 200 * vm.uiFactor,
      height: 240 * vm.uiFactor
    )
    .contextMenu(forSelectionType: String.self) { _ in } primaryAction: { _ in
      vm.playFilteredTracks()
    }
    .tableColumnHeaders(.hidden)
    .tableStyle(.inset)
    .contrast(colorScheme == .dark ? 1.5 : 1)
    .blendMode(colorScheme == .dark ? .plusLighter : .plusDarker)
    .modifier(TableSelectionHandler(
      selection: selection,
      allItems: items,
      onSelectionChange: onSelectionChange
    ))
  }
  #endif

  // MARK: - UIKit: Custom Button List with multi-select + modifier keys

  #if !canImport(AppKit) || targetEnvironment(macCatalyst)
  @ViewBuilder
  private func filterColumnCustomList(
    allLabel: String,
    items: [String],
    selection: Binding<Set<String>>,
    onSelectionChange: @escaping () -> Void
  )
    -> some View {
    let allItems = tableItems(allLabel: allLabel, items: items)
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(Array(allItems.enumerated()), id: \.offset) { index, item in
          ColumnBrowserRow(
            item: item,
            index: index,
            isSelected: item.value == Self.allOptionTag
              ? selection.wrappedValue.isEmpty
              : selection.wrappedValue.contains(item.value),
            onTap: {
              handleColumnTap(
                item: item, selection: selection,
                allItems: items, allLabel: allLabel,
                onSelectionChange: onSelectionChange
              )
            }
          )
        }
      }
      .padding(.vertical, 8)
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .frame(
      width: 200 * vm.uiFactor,
      height: 240 * vm.uiFactor
    )
  }

  /// Phase 73: Handles tap with modifier key awareness (Shift for range, Command for toggle).
  private func handleColumnTap(
    item: FilterTableItem,
    selection: Binding<Set<String>>,
    allItems: [String],
    allLabel: String,
    onSelectionChange: @escaping () -> Void
  ) {
    if item.value == Self.allOptionTag {
      selection.wrappedValue = []
      columnAnchors[allLabel] = nil
      onSelectionChange()
      return
    }
    let modifiers = ModifierKeyMonitor.shared.currentModifiers
    if modifiers.contains(.shift), let anchor = columnAnchors[allLabel],
       let anchorIdx = allItems.firstIndex(of: anchor),
       let clickIdx = allItems.firstIndex(of: item.value) {
      // Shift+Click: range select from anchor to clicked item.
      let rangeItems = Set(allItems[min(anchorIdx, clickIdx) ... max(anchorIdx, clickIdx)])
      if modifiers.contains(.command) {
        selection.wrappedValue.formUnion(rangeItems)
      } else {
        selection.wrappedValue = rangeItems
      }
    } else if modifiers.contains(.command) {
      // Command+Click: toggle individual item.
      if selection.wrappedValue.contains(item.value) {
        selection.wrappedValue.remove(item.value)
      } else {
        selection.wrappedValue.insert(item.value)
      }
      columnAnchors[allLabel] = item.value
    } else {
      // Plain tap: toggle for touch friendliness.
      if selection.wrappedValue.contains(item.value) {
        selection.wrappedValue.remove(item.value)
      } else {
        selection.wrappedValue.insert(item.value)
      }
      columnAnchors[allLabel] = item.value
    }
    selection.wrappedValue.remove(Self.allOptionTag)
    onSelectionChange()
  }
  #endif

  /// Build table items: prepend "All" entry, then list regular items.
  /// When "All" is in selection, clear it; when anything else is added, remove "All".
  private func tableItems(allLabel: String, items: [String]) -> [FilterTableItem] {
    var result = [FilterTableItem(value: Self.allOptionTag, label: allLabel)]
    result.append(contentsOf: items.map { FilterTableItem(value: $0, label: $0) })
    return result
  }
}

// MARK: - TableSelectionHandler (AppKit only)

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
/// Custom modifier to handle "All" row logic and cascade filtering.
private struct TableSelectionHandler: ViewModifier {
  // MARK: Lifecycle

  init(
    selection: Binding<Set<String>>,
    allItems: [String],
    onSelectionChange: @escaping () -> Void
  ) {
    self._selection = selection
    self.allItems = allItems
    self.onSelectionChange = onSelectionChange
  }

  // MARK: Internal

  func body(content: Content) -> some View {
    content
      .onChange(of: selection) { oldValue, newValue in
        // Check if ColumnBrowserView.allOptionTag was toggled
        let hadAll = oldValue.contains(ColumnBrowserView.allOptionTag)
        let hasAll = newValue.contains(ColumnBrowserView.allOptionTag)

        if hasAll, !hadAll {
          // "All" was just selected → clear selection (empty = all items)
          selection = []
          onSelectionChange()
        } else if !hasAll, hadAll {
          // "All" was just deselected → no-op, already cleared
          onSelectionChange()
        } else if hasAll, newValue.count > 1 {
          // If "All" is present with other items, remove ColumnBrowserView.allOptionTag (user selected a specific item)
          selection.remove(ColumnBrowserView.allOptionTag)
          onSelectionChange()
        } else {
          // Regular item toggled
          onSelectionChange()
        }
      }
  }

  // MARK: Private

  @Binding private var selection: Set<String>

  private let allItems: [String]
  private let onSelectionChange: () -> Void
}
#endif

// MARK: - ColumnBrowserRow (UIKit: custom selectable row)

#if !canImport(AppKit) || targetEnvironment(macCatalyst)
/// A single row in the UIKit Column Browser list.
/// Tap toggles selection; modifier keys (Shift/Command) are handled by the caller.
private struct ColumnBrowserRow: View {
  let item: FilterTableItem
  let index: Int
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Text(item.label)
      .font(.subheadline)
      .lineLimit(1)
      .truncationMode(.tail)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, OS.type == .macOS ? 6 : 8)
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .padding(.horizontal, 8)
      .contentShape(.rect)
      .onTapGesture {
        onTap()
      }
  }

  @ViewBuilder var background: some View {
    if isSelected {
      Color.accentColor.opacity(0.5)
    } else if !index.isMultiple(of: 2) {
      Color.gray.opacity(0.2)
    } else {
      Color.clear
    }
  }
}
#endif

// MARK: - FilterTableItem

private struct FilterTableItem: Identifiable {
  let value: String
  let label: String

  var id: String { value }
}
