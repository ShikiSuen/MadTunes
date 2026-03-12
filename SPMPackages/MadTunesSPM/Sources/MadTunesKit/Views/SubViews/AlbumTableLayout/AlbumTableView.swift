// (c) 2026 and onwards Shiki Suen (AGPL-3.0-or-later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - TableColumnType

/// Identifiers for table columns to support visibility toggling.
enum TableColumnType: String, CaseIterable, Identifiable {
  // Phase 46: Playing indicator column (always visible, first column)
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
    case .playingIndicator: "" // Phase 46: No text, uses SF Symbol in header
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
    case .playingIndicator: 28 // Phase 46: Compact width for speaker icon
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
      true // Phase 46: Always visible
    case .albumArtist, .albumTitle, .artist, .genre, .length, .name:
      true
    case .folder, .trackNumber, .year:
      false
    }
  }

  // Phase 46: Whether this column can be hidden by user
  var isHidable: Bool {
    switch self {
    case .playingIndicator: false // Phase 46: Cannot hide
    default: true
    }
  }
}

// MARK: - AlbumTableView

/// Custom table view using a single-column headerless SwiftUI `Table`.
///
/// Each track is rendered as a single row (HStack of cells) via the custom
/// `trackRow` builder. Selection, drag-selection, and basic keyboard
/// navigation are delegated to the system `Table`. Double-click fires
/// `onTrackDoubleClicked`; right-click shows a context menu. The column
/// header row at the bottom is independently managed.
struct AlbumTableView: View {
  // MARK: Lifecycle

  init(
    tracks: [Track],
    selectedTrackIDs: Binding<Set<UUID>>,
    currentTrackID: UUID? = nil,
    onTrackSingleClicked: @escaping (Track, [Track]) -> Void = { _, _ in },
    onTrackDoubleClicked: @escaping (Track, [Track]) -> Void = { _, _ in }
  ) {
    self.tracks = tracks
    self._selectedTrackIDs = selectedTrackIDs
    self.currentTrackID = currentTrackID
    self.onTrackSingleClicked = onTrackSingleClicked
    self.onTrackDoubleClicked = onTrackDoubleClicked
  }

  // MARK: Internal

  var body: some View {
    // Phase 48: Single-column headerless SwiftUI Table delegates
    // selection, drag-selection, and keyboard arrow navigation to the system.
    ScrollViewReader { proxy in
      Table(tracks, selection: $selectedTrackIDs) {
        TableColumn("Track".description) { track in
          trackRow(track)
            .id(track.id)
        }
      }
      .tableColumnHeaders(.hidden)
      .tableStyle(.inset)
      .contextMenu(forSelectionType: UUID.self, menu: { ids in
        let selected = tracks.filter { ids.contains($0.id) }
        if !selected.isEmpty {
          trackContextMenu(forTracks: selected)
        }
      }, primaryAction: { ids in
        // Double-click: play starting from the first selected track.
        guard let firstID = ids.first,
              let track = tracks.first(where: { $0.id == firstID }) else { return }
        onTrackDoubleClicked(track, tracks)
      })
      .onChange(of: vm.tableScrollTargetID) { _, newID in
        if let id = newID {
          Task {
            withAnimation(.easeInOut(duration: 0.3)) {
              proxy.scrollTo(id, anchor: .center)
            }
          }
          vm.tableScrollTargetID = nil
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      columnNameRow
        .fixedSize(horizontal: false, vertical: true)
        .frame(minWidth: 1, maxWidth: .infinity, alignment: .leading)
        .contextMenu {
          columnVisibilityMenu
        }
    }
    .sheet(isPresented: $isTrackInfoPresented) {
      trackInfoSheetContent
    }
    .alert(
      String(localized: "i18n:Alert.RemoveFromLibraryTitle", bundle: #bundle),
      isPresented: $showDeleteConfirmation
    ) {
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
      Button(String(localized: "i18n:Common.Remove", bundle: #bundle), role: .destructive) {
        let trackIDs = Set(tracksToDelete.map(\.id))
        vm.library.removeTracks(ids: trackIDs)
        tracksToDelete = []
      }
    } message: {
      Text(String(
        localized: "i18n:Alert.RemoveTracksMessage",
        defaultValue: "This will remove \(tracksToDelete.count) track(s) from the library. The original files will not be deleted.",
        bundle: #bundle
      ))
    }
    .alert(
      String(localized: "i18n:Sidebar.Alert.NewPlaylistTitle", bundle: #bundle),
      isPresented: $showNewPlaylistAlert
    ) {
      TextField(
        String(localized: "i18n:Sidebar.Alert.PlaylistNamePlaceholder", bundle: #bundle),
        text: $newPlaylistName
      )
      Button(String(localized: "i18n:Common.Create", bundle: #bundle)) {
        commitNewPlaylistAlert()
      }
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
    }
  }

  // MARK: Private

  @Binding private var selectedTrackIDs: Set<UUID>
  @State private var vm: MadTunesViewModel = .shared

  @State private var isTrackInfoPresented = false
  @State private var tracksForTrackInfo: [Track] = []
  @State private var detailedMetadataList: [DetailedTrackMetadata?] = []

  @State private var showDeleteConfirmation = false
  @State private var tracksToDelete: [Track] = []

  @State private var showNewPlaylistAlert = false
  @State private var newPlaylistName = ""
  @State private var trackIDsForNewPlaylist: Set<UUID> = []

  // Phase 43: Per-column widths (persisted to UserDefaults).
  @State private var columnWidths: [String: CGFloat] = {
    guard let data = UserDefaults.standard.data(forKey: TableColumnType.columnWidthsKey),
          let dict = try? JSONDecoder().decode([String: CGFloat].self, from: data) else {
      return [:]
    }
    return dict
  }()

  private let tracks: [Track]
  private let currentTrackID: UUID?
  private let onTrackSingleClicked: (Track, [Track]) -> Void
  private let onTrackDoubleClicked: (Track, [Track]) -> Void

  private var canvasWidth: CGFloat {
    vm.screenVM.mainColumnCanvasSizeObserved.width
  }

  private var visibleColumns: [TableColumnType] {
    // Phase 46: Ensure playingIndicator is always first and always visible
    let userVisible = TableColumnType.allCases.filter {
      $0 != .playingIndicator && isColumnVisible($0)
    }
    return [.playingIndicator] + (userVisible.isEmpty ? [.name] : userVisible)
  }

  // MARK: - Header

  @ViewBuilder private var columnNameRow: some View {
    HStack(spacing: 0) {
      ForEach(Array(visibleColumns.enumerated()), id: \.element) { index, column in
        let isLast = index == visibleColumns.count - 1
        columnHeaderButton(column)
          .frame(
            width: isLast ? nil : columnWidth(for: column),
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
    if tracksForTrackInfo.count == 1, let track = tracksForTrackInfo.first {
      TrackInfoView(
        track: track,
        detailedMetadata: detailedMetadataList.first ?? nil
      )
    } else {
      MultiTrackInfoView(
        tracks: tracksForTrackInfo,
        detailedMetadataList: detailedMetadataList
      )
    }
  }

  // Phase 43/46: Menu-style Picker with native Toggle checkmarks for column visibility.
  // Phase 46: Only show hidable columns (playingIndicator is always visible)
  @ViewBuilder private var columnVisibilityMenu: some View {
    Menu {
      ForEach(TableColumnType.allCases.filter(\.isHidable)) { column in
        Toggle(column.localizedName, isOn: Binding(
          get: { isColumnVisible(column) },
          set: { _ in toggleColumnVisibility(column) }
        ))
      }
    } label: {
      Label(
        String(localized: "i18n:Table.ColumnFilter.ToolbarButtonTitle", bundle: #bundle),
        systemImage: "tablecells"
      )
    }
  }

  // Phase 45: Sortable column header button
  @ViewBuilder
  // Phase 46: Column header button with speaker icon for playing indicator
  private func columnHeaderButton(_ column: TableColumnType) -> some View {
    if column == .playingIndicator {
      HStack(spacing: 4) {
        // Phase 46: Playing indicator column uses speaker icon
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
        vm.setTableSort(column: column)
      }) {
        HStack(spacing: 4) {
          Text(column.localizedName + (vm.sortIndicator(for: column) ?? ""))
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

  // Phase 43/45: Column divider for resizing
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
            handleColumnResize(column: column, translation: value.translation.width)
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

  // MARK: - Row

  @ViewBuilder
  private func trackRow(_ track: Track) -> some View {
    // Phase 45: Use HStack to match header layout exactly
    Color.clear
      .frame(height: 20)
      .overlay(alignment: .leading) {
        HStack(spacing: 0) {
          ForEach(Array(visibleColumns.enumerated()), id: \.element) { index, column in
            let isTrailingColumn = index == visibleColumns.count - 1
            let columnWidth = isTrailingColumn ? nil : columnWidth(for: column)
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
      .frame(minWidth: 1, maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Cell content

  // Phase 43/46: All user data uses Text(verbatim:) to prevent String Catalog pollution.
  @ViewBuilder
  private func cellContent(for track: Track, column: TableColumnType) -> some View {
    switch column {
    case .playingIndicator:
      // Phase 46: Playing indicator column shows speaker icon for current track
      if track.id == currentTrackID {
        Image(systemName: "speaker.wave.2.fill")
          .foregroundStyle(Color.primary)
          .font(.caption)
          .frame(width: 16)
      } else {
        Color.clear
          .frame(width: 16)
      }
    case .name:
      // Phase 46: Removed speaker icon (now in separate playingIndicator column)
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
      // Phase 46: Always show disc-track format, treating missing values as 0
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
      Text(verbatim: track.fileURL.deletingLastPathComponent().lastPathComponent)
        .help(Text(verbatim: track.fileURL.path(percentEncoded: false)))
    }
  }

  // MARK: - Context menu builder

  // Phase 48: Context menu for Table's forSelectionType API.
  @ViewBuilder
  private func trackContextMenu(forTracks selectedTracks: [Track]) -> some View {
    TrackContextMenu(
      tracks: selectedTracks,
      library: vm.library,
      audioPlayer: vm.player,
      currentPlaylistID: vm.selectedPlaylistID,
      isCurrentTrack: selectedTracks.count == 1 && selectedTracks.first?.id == currentTrackID,
      onShowTrackInfo: {
        tracksForTrackInfo = selectedTracks
        Task {
          var metadataList: [DetailedTrackMetadata?] = []
          for tr in tracksForTrackInfo {
            let metadata = await MetadataReader.readDetailedMetadata(from: tr.fileURL)
            metadataList.append(metadata)
          }
          detailedMetadataList = metadataList
          isTrackInfoPresented = true
        }
      },
      onShowDeleteConfirmation: {
        tracksToDelete = selectedTracks
        showDeleteConfirmation = true
      },
      onNewPlaylistWithTracks: { trackIDs in
        trackIDsForNewPlaylist = trackIDs
        newPlaylistName = ""
        showNewPlaylistAlert = true
      }
    )
  }

  // MARK: - Column visibility

  private func isColumnVisible(_ column: TableColumnType) -> Bool {
    vm.tableColumnVisibility[column.rawValue] ?? column.isDefaultVisible
  }

  private func toggleColumnVisibility(_ column: TableColumnType) {
    let currentValue = isColumnVisible(column)
    var newVisibility = vm.tableColumnVisibility
    newVisibility[column.rawValue] = !currentValue

    let allHidden = TableColumnType.allCases.allSatisfy {
      !(newVisibility[$0.rawValue] ?? $0.isDefaultVisible)
    }
    if allHidden {
      newVisibility[TableColumnType.name.rawValue] = true
    }

    vm.tableColumnVisibility = newVisibility

    if let data = try? JSONEncoder().encode(newVisibility) {
      UserDefaults.standard.set(data, forKey: TableColumnType.userDefaultsKey)
    }
  }

  // Phase 43: Dynamic column width helper.
  private func columnWidth(for column: TableColumnType) -> CGFloat {
    columnWidths[column.rawValue] ?? column.defaultWidth
  }

  // Phase 45: Handle column resize via drag gesture
  private func handleColumnResize(column: TableColumnType, translation: CGFloat) {
    let key = column.rawValue
    let currentWidth = columnWidths[key] ?? column.defaultWidth
    let newWidth = max(40, currentWidth + translation)
    columnWidths[key] = newWidth
    persistColumnWidths()
  }

  // Phase 43: Persist column widths to UserDefaults.
  private func persistColumnWidths() {
    if let data = try? JSONEncoder().encode(columnWidths) {
      UserDefaults.standard.set(data, forKey: TableColumnType.columnWidthsKey)
    }
  }

  private func commitNewPlaylistAlert() {
    let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    let existingNames = Set(vm.library.playlists.dropFirst(2).map(\.name))
    guard !existingNames.contains(name) else { return }
    vm.library.addPlaylist(name: name)
    if let newPlaylist = vm.library.playlists.last {
      vm.library.addTracks(trackIDsForNewPlaylist, toPlaylist: newPlaylist.id)
    }
    trackIDsForNewPlaylist = []
  }
}
