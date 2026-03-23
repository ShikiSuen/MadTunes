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

/// Custom table view with platform-specific backends.
///
/// **AppKit** (macOS native): Uses SwiftUI `Table` (SUNT — SwiftUI Native Table)
/// with a single column containing the full row HStack. The native NSTableView
/// backend handles selection, alternating rows, and keyboard navigation.
/// Drag-reorder uses `TableRow.draggable` + `ForEach.dropDestination`.
/// The built-in column header is hidden; the custom `columnNameRow` is used instead.
///
/// **UIKit** (iOS / iPadOS / Mac Catalyst): Uses `List` + `ForEach` with
/// `.onMove` for native drag-reorder. Selection and edit mode are handled
/// by the system `List`. Double-click on non-AppKit uses `.simultaneousGesture`.
///
/// Phase 41: Original creation. Phase 52: Table → List.
/// Phase 89: List → LazyVGrid (abandoned). Phase 90: SUNT (AppKit) + List (UIKit).
struct AlbumTableView: View {
  // MARK: Lifecycle

  /// Phase 62: Simplified init — selectedTrackIDs read from vm directly.
  init() {}

  // MARK: Internal

  var body: some View {
    ScrollViewReader { proxy in
      #if canImport(AppKit) && !canImport(UIKit)
      nativeTableList(scrollProxy: proxy)
      #else
      listTrackList(scrollProxy: proxy)
      #endif
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
        Task {
          await vm.removeTracksFromLibrary(trackIDs)
        }
        tableVM.tracksToDelete = []
      }
    } message: {
      Text("i18n:Alert.RemoveTracksMessage:\(tableVM.tracksToDelete.count)", bundle: #bundle)
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

  // MARK: - UIKit: List-based track list

  /// Phase 52 original design restored for UIKit targets.
  /// List + ForEach with .onMove for drag-reorder on reorderable playlists.
  #if !canImport(AppKit) || canImport(UIKit)
  private var listSyleProvided: some ListStyle { .inset }

  // Phase 71: Extracted helper to avoid type-checker explosion in trackList body.
  @ViewBuilder
  private func alternatingRowBackground(at index: Int, trackID: UUID) -> some View {
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

  @ViewBuilder
  private func listTrackList(scrollProxy proxy: ScrollViewProxy) -> some View {
    let canReorder = vm.tableVM.canReorderCurrentPlaylist
    // Phase 109: Snapshot column widths to avoid per-cell @Observable access.
    let cachedColumnWidths = tableVM.columnWidths
    // Phase 111: Snapshot visible columns to avoid per-row recomputation.
    let cachedVisibleColumns = visibleColumns
    List(selection: Bindable(vm).selectedTrackIDs) {
      ForEach(Array(tableVM.displayedTracks.enumerated()), id: \.element.id) { index, track in
        TableTrackRowView(
          track: track,
          index: index,
          visibleColumns: cachedVisibleColumns,
          currentTrackID: currentTrackID,
          isTrackSelected: vm.selectedTrackIDs.contains(track.id),
          columnWidths: cachedColumnWidths
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
        .listRowBackground(alternatingRowBackground(at: index, trackID: track.id))
        // Phase 111: Removed .drawingGroup() — per-row bitmap rasterization
        // adds significant overhead on macCatalyst/UIKit for simple text rows.
        .tag(track.id)
      }
      .onMove(perform: onRowMoveActionProvider(canReorder: canReorder))
    }
    .listStyle(listSyleProvided)
    .contextMenu(forSelectionType: UUID.self, menu: { ids in
      let selected = tableVM.displayedTracks.filter { ids.contains($0.id) }
      if !selected.isEmpty {
        trackContextMenu(forTracks: selected)
      }
    })
    .simultaneousGesture(
      TapGesture(count: 2).onEnded {
        onTrackDoubleClicked(vm.selectedTrackIDs)
      }
    )
    // Phase 69: Enable iOS multi-select when edit mode is active.
    .environment(\.editMode, .init(
      get: { tableVM.isEditModeActive ? .active : .inactive },
      set: { tableVM.isEditModeActive = ($0 == .active) }
    ))
    .onChange(of: vm.tableVM.tableScrollTargetID) { _, newID in
      if let id = newID {
        Task {
          withAnimation(.interactiveSpring.nerf(vm.gridVM.legacyHardwareMode)) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
        vm.tableVM.tableScrollTargetID = nil
      }
    }
  }
  #endif

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
    .disabled(tableVM.isEditModeActive)
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

  /// Phase 89: Migrated from List to ScrollView + LazyVGrid for performance.
  /// Phase 90 revised: LazyVGrid abandoned. AppKit uses SUNT, UIKit uses List.
  ///
  /// SUNT (SwiftUI Native Table) — single-column Table with custom row content.
  /// Uses NSTableView backend. Column header hidden via `.tableColumnHeaders(.hidden)`.
  /// Drag-reorder via TableRow.draggable + ForEach.dropDestination.
  #if canImport(AppKit) && !canImport(UIKit)
  @ViewBuilder
  private func nativeTableList(scrollProxy proxy: ScrollViewProxy) -> some View {
    let canReorder = vm.tableVM.canReorderCurrentPlaylist
    // Phase 109: Pre-compute index map for O(1) lookup per row,
    // replacing O(n) firstIndex(where:) that caused massive Track copying.
    let displayedTracks = tableVM.displayedTracks
    let indexMap = Dictionary(uniqueKeysWithValues: displayedTracks.enumerated().map { ($1.id, $0) })
    // Phase 109: Snapshot column widths to avoid per-cell @Observable access.
    let cachedColumnWidths = tableVM.columnWidths
    Table(of: Track.self, selection: Bindable(vm).selectedTrackIDs) {
      TableColumn("Tracks".description) { track in
        let index = indexMap[track.id] ?? 0
        TableTrackRowView(
          track: track,
          index: index,
          visibleColumns: visibleColumns,
          currentTrackID: currentTrackID,
          isTrackSelected: vm.selectedTrackIDs.contains(track.id),
          columnWidths: cachedColumnWidths
        )
      }
    } rows: {
      ForEach(displayedTracks) { track in
        if canReorder {
          TableRow(track)
            .draggable(track)
        } else {
          TableRow(track)
        }
      }
      .dropDestination(for: String.self) { index, uuidStrings in
        if canReorder {
          handleDropReorder(uuidStrings: uuidStrings, destinationIndex: index)
        }
      }
    }
    .tableColumnHeaders(.hidden)
    .contextMenu(forSelectionType: UUID.self, menu: { ids in
      let selected = tableVM.displayedTracks.filter { ids.contains($0.id) }
      if !selected.isEmpty {
        trackContextMenu(forTracks: selected)
      }
    }, primaryAction: { ids in
      onTrackDoubleClicked(ids)
    })
    .onChange(of: vm.tableVM.tableScrollTargetID) { _, newID in
      if let id = newID {
        Task {
          withAnimation(.interactiveSpring.nerf(vm.gridVM.legacyHardwareMode)) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
        vm.tableVM.tableScrollTargetID = nil
      }
    }
  }
  #endif

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

  // MARK: - List helpers (UIKit)

  #if !canImport(AppKit) || canImport(UIKit)
  private func onRowMoveActionProvider(canReorder: Bool? = nil) -> ((IndexSet, Int) -> Void)? {
    guard canReorder ?? vm.tableVM.canReorderCurrentPlaylist else { return nil }
    return handleOnMove
  }

  /// Phase 52: Handles the `.onMove` callback from ForEach drag-reorder.
  private func handleOnMove(_ source: IndexSet, _ destination: Int) {
    guard vm.tableVM.canReorderCurrentPlaylist else { return }
    let ids = source.map { tableVM.displayedTracks[$0].id }
    vm.tableVM.moveTracksInCurrentPlaylist(trackIDs: ids, toIndex: destination)
  }
  #endif

  private func onTrackDoubleClicked(_ ids: Set<UUID>) {
    guard let firstID = ids.first else { return }
    let track = tableVM.displayedTracks.first(where: { $0.id == firstID })
    guard let track else { return }
    let startIndex = tracks.firstIndex(where: { $0.id == track.id }) ?? 0
    Task {
      await vm.player.setQueue(tracks, startingAt: startIndex)
    }
  }

  // MARK: - Drag-and-Drop Reorder (AppKit SUNT)

  /// Phase 90: Drop handler for SUNT drag-reorder.
  /// Receives UUID strings (from Track's ProxyRepresentation), resolves to track IDs,
  /// and delegates to moveTracksInCurrentPlaylist.
  #if canImport(AppKit) && !canImport(UIKit)
  @discardableResult
  private func handleDropReorder(uuidStrings: [String], destinationIndex: Int) -> Bool {
    guard vm.tableVM.canReorderCurrentPlaylist else { return false }
    let draggedIDs = uuidStrings.compactMap(UUID.init(uuidString:))
    guard !draggedIDs.isEmpty else { return false }
    vm.tableVM.moveTracksInCurrentPlaylist(trackIDs: draggedIDs, toIndex: destinationIndex)
    return true
  }
  #endif
}

// MARK: - TableTrackRowView

/// Row view shared between SUNT (AppKit) and List (UIKit).
/// On AppKit/SUNT: no extra background, highlight, or foreground — the native
/// NSTableView handles selection highlighting and alternating row colors.
/// On UIKit/List: uses Phase 88 visibility-gated rendering with manual row background.
private struct TableTrackRowView: View {
  // MARK: Lifecycle

  init(
    track: Track,
    index: Int,
    visibleColumns: [TableColumnType],
    currentTrackID: UUID?,
    isTrackSelected: Bool,
    columnWidths: [String: CGFloat]
  ) {
    self.track = track
    self.index = index
    self.visibleColumns = visibleColumns
    self.currentTrackID = currentTrackID
    self.isTrackSelected = isTrackSelected
    self.columnWidths = columnWidths
  }

  // MARK: Internal

  var body: some View {
    #if canImport(AppKit) && !canImport(UIKit)
    // SUNT mode: bare row content, no extra styling.
    // Phase 109: Fixed height to short-circuit NSTableView's automatic
    // row height calculation (was ~25% of CPU in constraint solving).
    rowContent
      .frame(height: 20)
    #else
    // List mode: visibility-gated rendering with Phase 88 pattern.
    Color.clear
      .frame(height: 20)
      .overlay(alignment: .leading) {
        if isVisible {
          rowContent
        }
      }
      .clipShape(.rect)
      .contentShape(.rect)
      .frame(minWidth: 1, maxWidth: .infinity, alignment: .leading)
      .onAppear { isVisible = true }
      .onDisappear { isVisible = false }
    #endif
  }

  // MARK: Private

  #if !canImport(AppKit) || canImport(UIKit)
  @State private var isVisible = false
  #endif

  private let track: Track
  private let index: Int
  private let visibleColumns: [TableColumnType]
  private let currentTrackID: UUID?
  private let isTrackSelected: Bool
  // Phase 109: Snapshotted column widths, passed from parent to avoid
  // per-cell @Observable access and JSON decode during scroll.
  private let columnWidths: [String: CGFloat]

  @ViewBuilder private var rowContent: some View {
    HStack(spacing: 0) {
      ForEach(Array(visibleColumns.enumerated()), id: \.element) { colIdx, column in
        let isTrailingColumn = colIdx == visibleColumns.count - 1
        // Phase 109: Use snapshotted dictionary directly instead of ViewModel access.
        let colWidth: CGFloat? = isTrailingColumn ? nil : (columnWidths[column.rawValue] ?? column.defaultWidth)
        cellContent(for: column)
          .font(.callout)
          .lineLimit(1)
          .padding(.horizontal, 6)
          .frame(width: colWidth, alignment: .leading)
        if !isTrailingColumn {
          Spacer().frame(width: 1)
        }
      }
    }
  }

  // Phase 42/46: All user data uses Text(verbatim:) to prevent String Catalog pollution.
  @ViewBuilder
  private func cellContent(for column: TableColumnType) -> some View {
    switch column {
    case .playingIndicator:
      if track.id == currentTrackID {
        Image(systemName: "speaker.wave.2.fill")
          .font(.caption)
          .frame(width: 16)
      } else {
        Color.clear
          .frame(width: 16)
      }
    case .name:
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
}
