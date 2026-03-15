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

      if vm.screenVM.windowSizeObserved.width < 810 {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
          GridRow {
            view1
            view4
          }
          GridRow {
            view2
            view3
          }
        }
      } else {
        ViewThatFits {
          Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
              view1
              view2
              view3
              view4
            }
          }
        }
      }
    }
    .fixedSize()
  }

  // MARK: Private

  @State private var vm: MadTunesViewModel = .shared
  @Environment(\.colorScheme) private var colorScheme

  // MARK: - Table-based filter column

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
      Text(verbatim: title)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
          Rectangle()
            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        }
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
      #if os(macOS)
      .contextMenu(forSelectionType: String.self) { _ in } primaryAction: { _ in
        vm.playFilteredTracks()
      }
      #else
        // On iOS, we purposely avoid attaching a primary action to prevent "double-tap to play" behavior.
      .contextMenu(forSelectionType: String.self) { _ in }
      #endif
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
  }

  /// Build table items: prepend "All" entry, then list regular items.
  /// When "All" is in selection, clear it; when anything else is added, remove "All".
  private func tableItems(allLabel: String, items: [String]) -> [FilterTableItem] {
    var result = [FilterTableItem(value: "__all__", label: allLabel)]
    result.append(contentsOf: items.map { FilterTableItem(value: $0, label: $0) })
    return result
  }
}

// MARK: - TableSelectionHandler

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
        // Check if "__all__" was toggled
        let hadAll = oldValue.contains("__all__")
        let hasAll = newValue.contains("__all__")

        if hasAll, !hadAll {
          // "All" was just selected → clear selection (empty = all items)
          selection = []
          onSelectionChange()
        } else if !hasAll, hadAll {
          // "All" was just deselected → no-op, already cleared
          onSelectionChange()
        } else if hasAll, newValue.count > 1 {
          // If "All" is present with other items, remove "__all__" (user selected a specific item)
          selection.remove("__all__")
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

// MARK: - FilterTableItem

private struct FilterTableItem: Identifiable {
  let value: String
  let label: String

  var id: String { value }
}
