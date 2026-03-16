// (c) 2026 and onwards Shiki Suen (AGPL-3.0-or-later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - TableColumnType

/// Identifiers for table columns to support visibility toggling.
enum TableColumnType: String, CaseIterable, Identifiable {
  // Phase 45: Playing indicator column (always visible, first column)
  case playingIndicator = "PlayingIndicator"
  case trackNumber = "TrackNumber"
  case name = "Name"
  case length = "Length"
  case artist = "Artist"
  case albumTitle = "AlbumTitle"
  case albumArtist = "AlbumArtist"
  case genre = "Genre"
  case year = "Year"
  case folder = "Folder"

  // MARK: Internal

  static let userDefaultsKey = "MadTunes.tableColumnVisibility"
  static let columnWidthsKey = "MadTunes.tableColumnWidths"

  var id: String { rawValue }

  var localizedName: String {
    switch self {
    case .playingIndicator: "" // Phase 45: No text, uses SF Symbol in header
    case .name: String(localized: "i18n:Table.Column.Name", bundle: #bundle)
    case .length: String(localized: "i18n:Table.Column.Length", bundle: #bundle)
    case .artist: String(localized: "i18n:Table.Column.Artist", bundle: #bundle)
    case .albumTitle: String(localized: "i18n:Table.Column.AlbumTitle", bundle: #bundle)
    case .albumArtist: String(localized: "i18n:Table.Column.AlbumArtist", bundle: #bundle)
    case .trackNumber: String(localized: "i18n:Table.Column.TrackNumber", bundle: #bundle)
    case .genre: String(localized: "i18n:Table.Column.Genre", bundle: #bundle)
    case .year: String(localized: "i18n:Table.Column.Year", bundle: #bundle)
    case .folder: String(localized: "i18n:Table.Column.Folder", bundle: #bundle)
    }
  }

  var defaultWidth: CGFloat {
    switch self {
    case .playingIndicator: 28 // Phase 45: Compact width for speaker icon
    case .name: 250
    case .length: 60
    case .artist: 150
    case .albumTitle: 150
    case .albumArtist: 150
    case .trackNumber: 65
    case .genre: 100
    case .year: 60
    case .folder: 150
    }
  }

  var isDefaultVisible: Bool {
    switch self {
    case .playingIndicator:
      true // Phase 45: Always visible
    case .albumArtist, .albumTitle, .artist, .genre, .length, .name:
      true
    case .folder, .trackNumber, .year:
      false
    }
  }

  // Phase 45: Whether this column can be hidden by user
  var isHidable: Bool {
    switch self {
    case .playingIndicator: false // Phase 45: Cannot hide
    default: true
    }
  }
}

// MARK: - AlbumTableView

/// Custom table view using a SwiftUI `List` with manual column layout.
///
/// Each track is rendered as a single row (HStack of cells) via the custom
/// `trackRow` builder. Selection and basic keyboard navigation are delegated
/// to the system `List`. Double-click fires `onTrackDoubleClicked`; right-click
/// shows a context menu. The column header row at the bottom is independently
/// managed.
///
/// Phase 52: Migrated from `Table` to `List` + `ForEach` so that `.onMove`
/// can provide native drag-reorder for playlist tracks. `Table` intercepted
/// both row-level drag gestures and Option+Arrow key events, making both
/// drag-reorder and keyboard-reorder impossible to implement.
struct AlbumTableView: View {
  // MARK: Lifecycle

  /// Phase 62: Simplified init — selectedTrackIDs read from vm directly.
  init() {}

  // MARK: Internal

  var body: some View {
    // Phase 52: List + ForEach replaces the single-column headerless Table.
    // This enables native .onMove drag-reorder and avoids Table's interception
    // of row-level gestures and Option+Arrow key events.
    ScrollViewReader { proxy in
      trackList(scrollProxy: proxy)
    }
    .safeAreaInset(edge: .bottom) {
      columnNameRow
        .fixedSize(horizontal: false, vertical: true)
        .frame(minWidth: 1, maxWidth: .infinity, alignment: .leading)
        .contextMenu {
          columnVisibilityMenu
        }
    }
    .sheet(isPresented: Bindable(tableVM).isTrackInfoPresented) {
      trackInfoSheetContent
    }
    .alert(
      String(localized: "i18n:Alert.RemoveFromLibraryTitle", bundle: #bundle),
      isPresented: Bindable(tableVM).showDeleteConfirmation
    ) {
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
      Button(String(localized: "i18n:Common.Remove", bundle: #bundle), role: .destructive) {
        let trackIDs = Set(tableVM.tracksToDelete.map(\.id))
        vm.library.removeTracks(ids: trackIDs)
        vm.invalidateSearchCacheForRemovedTracks(trackIDs)
        tableVM.tracksToDelete = []
      }
    } message: {
      Text(String(
        localized: "i18n:Alert.RemoveTracksMessage",
        defaultValue: "This will remove \(tableVM.tracksToDelete.count) track(s) from the library. The original files will not be deleted.",
        bundle: #bundle
      ))
    }
    .alert(
      String(localized: "i18n:Sidebar.Alert.NewPlaylistTitle", bundle: #bundle),
      isPresented: Bindable(tableVM).showNewPlaylistAlert
    ) {
      TextField(
        String(localized: "i18n:Sidebar.Alert.PlaylistNamePlaceholder", bundle: #bundle),
        text: Bindable(tableVM).newPlaylistName
      )
      Button(String(localized: "i18n:Common.Create", bundle: #bundle)) {
        tableVM.commitNewPlaylistAlert(library: vm.library)
      }
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
    }
  }

  // MARK: Private

  @State private var vm: MadTunesViewModel = .shared

  // Phase 53: Only show playing indicator when actively playing.
  private var currentTrackID: UUID? {
    vm.player.isPlaying ? vm.player.currentTrack?.id : nil
  }

  private var tracks: [Track] {
    vm.tableVM.currentTracksDisplayed
  }

  // Phase 60: Sub-ViewModel reference.
  private var tableVM: AlbumTableViewModel { vm.tableVM }

  private var canvasWidth: CGFloat {
    vm.screenVM.mainColumnCanvasSizeObserved.width
  }

  private var visibleColumns: [TableColumnType] {
    tableVM.visibleColumns
  }

  private var listSyleProvided: some ListStyle {
    #if os(macOS)
    .inset(alternatesRowBackgrounds: true)
    #else
    .inset
    #endif
  }

  // MARK: - Header

  @ViewBuilder private var columnNameRow: some View {
    HStack(spacing: 0) {
      ForEach(Array(visibleColumns.enumerated()), id: \.element) { index, column in
        let isLast = index == visibleColumns.count - 1
        columnHeaderButton(column)
          .frame(
            width: isLast ? nil : tableVM.columnWidth(for: column),
            height: 28,
            alignment: .leading
          )
        if !isLast {
          columnDivider(after: column)
            .frame(height: 28)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal)
    .background(.ultraThinMaterial)
  }

  // MARK: - Sheet / bar helpers

  @ViewBuilder private var trackInfoSheetContent: some View {
    if tableVM.tracksForTrackInfo.count == 1, let track = tableVM.tracksForTrackInfo.first {
      TrackInfoView(
        track: track,
        detailedMetadata: tableVM.detailedMetadataList.first ?? nil
      )
    } else {
      MultiTrackInfoView(
        tracks: tableVM.tracksForTrackInfo,
        detailedMetadataList: tableVM.detailedMetadataList
      )
    }
  }

  // Phase 42/46: Menu-style Picker with native Toggle checkmarks for column visibility.
  // Phase 45: Only show hidable columns (playingIndicator is always visible)
  @ViewBuilder private var columnVisibilityMenu: some View {
    ForEach(TableColumnType.allCases.filter(\.isHidable)) { column in
      Toggle(column.localizedName, isOn: Binding(
        get: { tableVM.isColumnVisible(column) },
        set: { _ in tableVM.toggleColumnVisibility(column) }
      ))
    }
  }

  // Phase 71: Extracted helper to avoid type-checker explosion in trackList body.
  @ViewBuilder
  private func alternatingRowBackground(at index: Int, trackID: UUID) -> some View {
    if !OS.isAppKit {
      let isHighlighted = vm.selectedTrackIDs.contains(trackID)
      if isHighlighted {
        Color.accentColor
          .clipShape(.capsule)
          .allowsHitTesting(false)
      } else if !index.isMultiple(of: 2) {
        LinearGradient(
          colors: [
            .clear,
            .secondary,
            .secondary,
            .secondary,
            .secondary,
            .secondary,
            .secondary,
            .clear,
          ],
          startPoint: .leading,
          endPoint: .trailing
        ).opacity(0.08)
          .clipShape(.capsule)
          .allowsHitTesting(false)
      }
    }
  }

  // Phase 44: Sortable column header button
  @ViewBuilder
  // Phase 45: Column header button with speaker icon for playing indicator
  private func columnHeaderButton(_ column: TableColumnType) -> some View {
    if column == .playingIndicator {
      HStack(spacing: 4) {
        // Phase 45: Playing indicator column uses speaker icon
        Image(systemName: "speaker.wave.2.fill")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 6)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .background(Color.clear)
      .contentShape(.rect)
    } else {
      Button(action: {
        vm.tableVM.setTableSort(column: column)
      }) {
        HStack(spacing: 4) {
          Text(column.localizedName + (vm.tableVM.sortIndicator(for: column) ?? ""))
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.clear)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
    }
  }

  // Phase 42/45: Column divider for resizing
  @ViewBuilder
  private func columnDivider(after column: TableColumnType) -> some View {
    Rectangle()
      .fill(Color.gray.opacity(0.3))
      .frame(width: 1)
      .overlay(
        Rectangle()
          .fill(Color.clear)
          .frame(width: 5)
          .contentShape(.rect)
      )
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            tableVM.handleColumnResize(column: column, translation: value.translation.width)
          }
      )
      .onHover { isHovering in
        #if canImport(AppKit)
        if isHovering {
          NSCursor.resizeLeftRight.set()
        } else {
          NSCursor.arrow.set()
        }
        #endif
      }
  }

  @ViewBuilder
  private func trackList(scrollProxy proxy: ScrollViewProxy) -> some View {
    let canReorder = vm.tableVM.canReorderCurrentPlaylist
    List(selection: Bindable(vm).selectedTrackIDs) {
      // Phase 52: Conditionally apply .onMove — only for playlists that
      // support reordering. This prevents List from showing drag affordances
      // on All Music, dynamic playlists, or when sorting/filtering is active.
      ForEach(Array(tableVM.displayedTracks.enumerated()), id: \.offset) { index, track in
        trackRow(track)
          .id(track.id)
          .tag(track.id)
          .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
          // Phase 71: Manual alternating row backgrounds for UIKit targets.
          .listRowBackground(alternatingRowBackground(at: index, trackID: track.id))
      }
      .onMove(perform: onRowMoveActionProvider(canReorder: canReorder))
    }
    .listStyle(listSyleProvided)
    .onAppear {
      tableVM.scheduleDisplayedTracksUpdate(to: tracks)
    }
    .onChange(of: tracks) { _, newValue in
      tableVM.scheduleDisplayedTracksUpdate(to: newValue)
    }
    .contextMenu(forSelectionType: UUID.self, menu: { ids in
      let selected = tableVM.displayedTracks.filter { ids.contains($0.id) }
      if !selected.isEmpty {
        trackContextMenu(forTracks: selected)
      }
    }, primaryAction: givePrimaryTableAction())
    .onChange(of: vm.tableVM.tableScrollTargetID) { _, newID in
      if let id = newID {
        Task {
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
        vm.tableVM.tableScrollTargetID = nil
      }
    }
    #if !(canImport(AppKit) && !canImport(UIKit))
    .simultaneousGesture(
      TapGesture(count: 2).onEnded {
        // Double-click: play starting from the first selected track.
        onTrackDoubleClicked(vm.selectedTrackIDs)
      }
    )
    // Phase 69: Enable iOS multi-select when edit mode is active.
    .environment(\.editMode, .init(
      get: { tableVM.isEditModeActive ? .active : .inactive },
      set: { tableVM.isEditModeActive = ($0 == .active) }
    ))
    #endif
  }

  // MARK: - Row

  @ViewBuilder
  private func trackRow(_ track: Track) -> some View {
    // Phase 44: Use HStack to match header layout exactly
    Color.clear
      .frame(height: 20)
      .overlay(alignment: .leading) {
        HStack(spacing: 0) {
          ForEach(Array(visibleColumns.enumerated()), id: \.element) { index, column in
            let isTrailingColumn = index == visibleColumns.count - 1
            let columnWidth = isTrailingColumn ? nil : tableVM.columnWidth(for: column)
            cellContent(for: track, column: column)
              .font(.callout)
              .lineLimit(1)
              .padding(.horizontal, 6)
              .frame(width: columnWidth, alignment: .leading)
            // Add spacer between columns (except last) to match header dividers
            if !isTrailingColumn {
              Spacer().frame(width: 1)
            }
          }
        }
      }
      .clipShape(.rect)
      .contentShape(.rect)
      .frame(minWidth: 1, maxWidth: .infinity, alignment: .leading)
      .drawingGroup()
  }

  // Phase 42/46: All user data uses Text(verbatim:) to prevent String Catalog pollution.
  @ViewBuilder
  private func cellContent(for track: Track, column: TableColumnType) -> some View {
    switch column {
    case .playingIndicator:
      // Phase 45: Playing indicator column shows speaker icon for current track
      if track.id == currentTrackID {
        Image(systemName: "speaker.wave.2.fill")
          .foregroundStyle(
            vm.selectedTrackIDs.contains(track.id) ? Color.white : Color.primary
          )
          .font(.caption)
          .frame(width: 16)
      } else {
        Color.clear
          .frame(width: 16)
      }
    case .name:
      // Phase 45: Removed speaker icon (now in separate playingIndicator column)
      Text(verbatim: track.title)
        .help(Text(verbatim: track.title))
    case .length:
      Text(verbatim: formatDuration(track.duration))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .help(Text(verbatim: formatDuration(track.duration)))
    case .artist:
      Text(verbatim: track.artist)
        .help(Text(verbatim: track.artist))
    case .albumTitle:
      Text(verbatim: track.albumTitle)
        .help(Text(verbatim: track.albumTitle))
    case .albumArtist:
      Text(verbatim: track.albumArtist)
        .help(Text(verbatim: track.albumArtist))
    case .trackNumber:
      // Phase 45: Always show disc-track format, treating missing values as 0
      let disc = max(0, track.discNumber)
      let trackNum = max(0, track.trackNumber)
      Text(verbatim: "\(disc)-\(String(format: "%02d", trackNum))")
        .monospacedDigit()
        .help(Text(verbatim: "\(disc)-\(trackNum)"))
    case .genre:
      Text(verbatim: track.genre)
        .help(Text(verbatim: track.genre))
    case .year:
      Text(verbatim: track.year.map(String.init) ?? "")
        .monospacedDigit()
        .help(Text(verbatim: track.year.map(String.init) ?? ""))
    case .folder:
      Text(verbatim: (track.folderPath as NSString).lastPathComponent)
        .help(Text(verbatim: track.fileURL.path(percentEncoded: false)))
    }
  }

  // MARK: - Context menu builder

  // Phase 47: Context menu for Table's forSelectionType API.
  @ViewBuilder
  private func trackContextMenu(forTracks selectedTracks: [Track]) -> some View {
    TrackContextMenu(
      tracks: selectedTracks,
      library: vm.library,
      audioPlayer: vm.player,
      currentPlaylistID: vm.selectedPlaylistID,
      isCurrentTrack: selectedTracks.count == 1 && selectedTracks.first?.id == currentTrackID,
      onShowTrackInfo: {
        tableVM.tracksForTrackInfo = selectedTracks
        Task {
          var metadataList: [DetailedTrackMetadata?] = []
          for tr in tableVM.tracksForTrackInfo {
            let metadata = await MetadataReader.readDetailedMetadata(from: tr.fileURL)
            metadataList.append(metadata)
          }
          tableVM.detailedMetadataList = metadataList
          tableVM.isTrackInfoPresented = true
        }
      },
      onShowDeleteConfirmation: {
        tableVM.tracksToDelete = selectedTracks
        tableVM.showDeleteConfirmation = true
      },
      onNewPlaylistWithTracks: { trackIDs in
        tableVM.trackIDsForNewPlaylist = trackIDs
        tableVM.newPlaylistName = ""
        tableVM.showNewPlaylistAlert = true
      }
    )
  }

  // MARK: - List

  private func onRowMoveActionProvider(canReorder: Bool? = nil) -> ((IndexSet, Int) -> Void)? {
    guard canReorder ?? vm.tableVM.canReorderCurrentPlaylist else { return nil }
    return handleOnMove
  }

  private func givePrimaryTableAction() -> ((Set<UUID>) -> Void)? {
    #if canImport(AppKit) && !canImport(UIKit)
    return onTrackDoubleClicked
    #else
    return nil
    #endif
  }

  private func onTrackDoubleClicked(_ ids: Set<UUID>) {
    guard let firstID = ids.first else { return }
    let track = tableVM.displayedTracks.first(where: { $0.id == firstID })
    guard let track else { return }
    // when a user double-clicks in the table we treat it as playing
    // the full filtered list beginning at that track
    let startIndex = tracks.firstIndex(where: { $0.id == track.id }) ?? 0
    vm.player.setQueue(tracks, startingAt: startIndex)
  }

  /// Phase 52: Handles the `.onMove` callback from ForEach drag-reorder.
  /// Translates IndexSet + destination into the `moveTracks` API.
  private func handleOnMove(_ source: IndexSet, _ destination: Int) {
    guard vm.tableVM.canReorderCurrentPlaylist else { return }
    let ids = source.map { tableVM.displayedTracks[$0].id }
    vm.tableVM.moveTracksInCurrentPlaylist(trackIDs: ids, toIndex: destination)
  }
}
