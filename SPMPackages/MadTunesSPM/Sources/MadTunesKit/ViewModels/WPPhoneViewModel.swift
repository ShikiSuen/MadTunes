// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import Observation
import SwiftUI

// MARK: - WPPhoneViewModel

/// Phase 75: Sub-ViewModel for the Windows Phone Metro-style iPhone UI.
/// Manages Panorama section navigation, tile layout, accent color,
/// and phone-specific state.
@Observable
@MainActor
final class WPPhoneViewModel {
  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  // MARK: - Panorama Section

  enum PanoramaSection: Int, CaseIterable, Identifiable {
    case nowPlaying = 0
    case library = 1
    case playlists = 2
    case search = 3

    // MARK: Internal

    var id: Int { rawValue }

    var localizedTitle: String {
      switch self {
      case .nowPlaying:
        String(localized: "i18n:WP.Section.NowPlaying", bundle: #bundle)
      case .library:
        String(localized: "i18n:WP.Section.Library", bundle: #bundle)
      case .playlists:
        String(localized: "i18n:WP.Section.Playlists", bundle: #bundle)
      case .search:
        String(localized: "i18n:WP.Section.Search", bundle: #bundle)
      }
    }
  }

  // MARK: - Library Pivot

  enum LibraryPivot: Int, CaseIterable, Identifiable {
    case albums = 0
    case artists = 1
    case tracks = 2
    case recentlyAdded = 3

    // MARK: Internal

    var id: Int { rawValue }

    var localizedTitle: String {
      switch self {
      case .albums:
        String(localized: "i18n:WP.Pivot.Albums", bundle: #bundle)
      case .artists:
        String(localized: "i18n:WP.Pivot.Artists", bundle: #bundle)
      case .tracks:
        String(localized: "i18n:WP.Pivot.Tracks", bundle: #bundle)
      case .recentlyAdded:
        String(localized: "i18n:WP.Pivot.RecentlyAdded", bundle: #bundle)
      }
    }
  }

  // MARK: - Tile Layout

  enum TileSize: Sendable {
    case large // 2×2
    case medium // 2×1
    case small // 1×1
  }

  // MARK: - WP Accent Color

  enum WPAccentColor: String, CaseIterable, Identifiable {
    case cobalt
    case crimson
    case emerald
    case mango
    case teal
    case steel

    // MARK: Internal

    var id: String { rawValue }

    var color: Color {
      switch self {
      case .cobalt: Color(red: 0, green: 80.0 / 255, blue: 239.0 / 255)
      case .crimson: Color(red: 162.0 / 255, green: 0, blue: 37.0 / 255)
      case .emerald: Color(red: 0, green: 138.0 / 255, blue: 0)
      case .mango: Color(red: 240.0 / 255, green: 150.0 / 255, blue: 9.0 / 255)
      case .teal: Color(red: 0, green: 171.0 / 255, blue: 169.0 / 255)
      case .steel: Color(red: 100.0 / 255, green: 118.0 / 255, blue: 135.0 / 255)
      }
    }

    var localizedName: String {
      switch self {
      case .cobalt: "Cobalt"
      case .crimson: "Crimson"
      case .emerald: "Emerald"
      case .mango: "Mango"
      case .teal: "Teal"
      case .steel: "Steel"
      }
    }
  }

  weak var mainVM: MadTunesViewModel?

  // MARK: - WPUI Selection Mode (Phase 83)

  /// Album IDs selected in WPUI multi-select mode.
  /// Separate from `AlbumGridViewModel.highlightedAlbumIDs` to avoid cross-UI contamination.
  var wpSelectedAlbumIDs: Set<UUID> = []

  // MARK: - Phase 124: WPUI Track Selection Mode

  /// Track IDs selected in WPUI playlist track multi-select mode.
  var wpSelectedTrackIDs: Set<UUID> = []

  var currentPivot: LibraryPivot = .albums

  // MARK: - Navigation State

  /// Album being viewed in detail (pushed via NavigationStack).
  var selectedAlbumForDetail: Album?

  /// Playlist being viewed in detail.
  var selectedPlaylistForDetail: Playlist?

  /// Artist being viewed (shows albums by that artist).
  var selectedArtistForDetail: String?

  /// Navigation path for drill-down views.
  var navigationPath = NavigationPath()

  // MARK: - Search

  var phoneSearchText: String = ""

  // MARK: - Context Menu State

  /// Albums pending delete confirmation.
  var albumsToDelete: [Album] = []
  var showDeleteConfirmation = false

  /// Tracks for TrackInfo sheet.
  var tracksForTrackInfo: [Track] = []
  /// Tracks pending delete confirmation (individual track delete).
  var tracksToDelete: [Track] = []
  var showTrackDeleteConfirmation = false

  /// New playlist creation from context menu.
  var showNewPlaylistAlert = false
  var newPlaylistName = ""
  var trackIDsForNewPlaylist: Set<UUID> = []

  // MARK: - Phase 78: Column Browser & Queue & Accent Picker

  /// Column Browser sheet presentation.
  var isColumnBrowserPresented = false

  /// Playing Queue sheet presentation.
  var isQueuePresented = false

  /// Accent Color picker sheet presentation.
  var isAccentColorPickerPresented = false

  /// Playlist rename alert.
  var isRenamePlaylistAlertPresented = false
  var renamePlaylistID: UUID?
  var renamePlaylistName = ""

  // Phase 174: didSet clears companion state on esc/gesture dismiss.
  var isTrackInfoPresented = false {
    didSet {
      if !isTrackInfoPresented {
        tracksForTrackInfo = []
      }
    }
  }

  var currentSection: PanoramaSection {
    get { access(keyPath: \.currentSection); return _currentSection }
    set { withMutation(keyPath: \.currentSection) { _currentSection = newValue } }
  }

  var recentAlbumKeys: [String] {
    get { access(keyPath: \.recentAlbumKeys); return _recentAlbumKeys }
    set { withMutation(keyPath: \.recentAlbumKeys) { _recentAlbumKeys = newValue } }
  }

  var isWPSelectionModeActive: Bool { !wpSelectedAlbumIDs.isEmpty }

  /// Phase 124: Whether WPUI track selection mode is active.
  var isWPTrackSelectionModeActive: Bool { !wpSelectedTrackIDs.isEmpty }

  var wpAccentColor: WPAccentColor {
    get { access(keyPath: \.wpAccentColor); return _wpAccentColor }
    set { withMutation(keyPath: \.wpAccentColor) { _wpAccentColor = newValue } }
  }

  /// Unique artists derived from current albums.
  var uniqueArtists: [String] {
    guard let mainVM else { return [] }
    let artists = Set(mainVM.gridVM.currentAlbumsDisplayed.map(\.artist))
    return artists.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  /// Tracks sorted by import order (most recent first) for the "Recently Added" pivot.
  var recentlyAddedTracks: [Track] {
    guard let mainVM else { return [] }
    // Tracks are stored in import order; reverse to show newest first.
    return Array(mainVM.filteredTracksBase.reversed())
  }

  /// Filtered search results for the phone search section.
  var phoneSearchResults: (albums: [Album], tracks: [Track]) {
    guard let mainVM else { return ([], []) }
    let tokens = searchTokens(from: phoneSearchText)
    guard !tokens.isEmpty else { return ([], []) }

    let matchingTracks = mainVM.filteredTracksBase.filter {
      mainVM.trackMatchesSearch($0, tokens: tokens, mode: .either)
    }

    // Build albums from matching tracks.
    var albumDict: [String: [Track]] = [:]
    for track in matchingTracks {
      let key = "\(track.albumTitle)||||\(track.albumArtist)"
      albumDict[key, default: []].append(track)
    }
    let albums = albumDict.compactMap { _, tracks -> Album? in
      guard let first = tracks.first else { return nil }
      return Album(
        id: UUID(),
        title: first.albumTitle,
        artist: first.albumArtist,
        tracks: tracks
      )
    }.sorted { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }

    return (albums, matchingTracks)
  }

  /// Whether WPUI should be used (iPhone always, compact iPad in portrait).
  static func shouldUseWPUI(screenVM: ScreenVM) -> Bool {
    switch OS.type {
    case .iPhoneOS: return true
    case .macOS: return false
    default: return screenVM.isHorizontallyCompact
    }
  }

  // MARK: - Phase 96: ViewModel-level Observations

  /// Called by MadTunesViewModel after mainVM is assigned.
  func setupObservations() {
    observeCurrentTrackForActivity()
    observeImportCompletion()
  }

  /// Determines tile size based on album position.
  /// Phase 124: Removed favorites-based medium sizing — all albums except index 0 are now small.
  func tileSizeForAlbum(_: Album, index: Int) -> TileSize {
    if index == 0 { return .large }
    return .small
  }

  /// Albums for a specific artist.
  func albumsForArtist(_ artist: String) -> [Album] {
    guard let mainVM else { return [] }
    return mainVM.gridVM.currentAlbumsDisplayed.filter { $0.artist == artist }
  }

  /// Commit creation of a new playlist from context menu.
  func commitNewPlaylist() {
    guard let mainVM else { return }
    let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    let existingNames = Set(mainVM.library.playlists.dropFirst(2).map(\.name))
    guard !existingNames.contains(name) else { return }
    mainVM.library.addPlaylist(name: name)
    if let newPlaylist = mainVM.library.playlists.last {
      mainVM.library.addTracks(trackIDsForNewPlaylist, toPlaylist: newPlaylist.id)
    }
    trackIDsForNewPlaylist = []
  }

  /// Phase 78: Rename an existing playlist.
  func commitRenamePlaylist() {
    guard let mainVM, let id = renamePlaylistID else { return }
    let name = renamePlaylistName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    mainVM.library.renamePlaylist(id: id, newName: name)
    renamePlaylistID = nil
    renamePlaylistName = ""
  }

  /// Record album activity (play or import) for recent-first tile ordering.
  func recordAlbumActivity(title: String, artist: String) {
    let key = "\(title):::\(artist)"
    recentAlbumKeys.removeAll { $0 == key }
    recentAlbumKeys.insert(key, at: 0)
    if recentAlbumKeys.count > 10 {
      recentAlbumKeys = Array(recentAlbumKeys.prefix(10))
    }
  }

  /// Record newly imported albums that aren't yet in the recent list.
  func recordNewlyImportedAlbums(from albums: [Album]) {
    let knownKeys = Set(recentAlbumKeys)
    let newAlbums = albums.filter { !knownKeys.contains("\($0.title):::\($0.artist)") }
    for album in newAlbums {
      recordAlbumActivity(title: album.title, artist: album.artist)
    }
  }

  /// Reorder albums so recently played/imported ones appear first.
  func albumsWithRecentFirst(_ albums: [Album]) -> [Album] {
    guard !recentAlbumKeys.isEmpty else { return albums }
    let keyToIndex = Dictionary(
      uniqueKeysWithValues: recentAlbumKeys.enumerated().map { ($1, $0) }
    )
    var recent: [(Int, Album)] = []
    var rest: [Album] = []
    for album in albums {
      let key = "\(album.title):::\(album.artist)"
      if let idx = keyToIndex[key] {
        recent.append((idx, album))
      } else {
        rest.append(album)
      }
    }
    recent.sort { $0.0 < $1.0 }
    return recent.map(\.1) + rest
  }

  /// Phase 86: Pop navigation stack entries that reference deleted albums or playlists.
  func popNavigationIfDataInvalid(library: MusicLibrary) {
    guard !navigationPath.isEmpty else { return }
    // NavigationPath doesn't support inspection of individual entries,
    // so we reset to root when deletion happens during drill-down.
    // This is the safest approach to avoid stale-snapshot views.
    navigationPath = NavigationPath()
  }

  // MARK: Private

  /// Currently displayed Panorama section.
  /// Phase 97: @AppStorage + @ObservationIgnored bridge (replaces manual UserDefaults + observation chain).
  @ObservationIgnored @AppStorage(wrappedValue: .library, "MadTunes.WPUI.lastSection")
  private var _currentSection: PanoramaSection

  // MARK: - Phase 84: Recent Album Tracking

  /// Album keys recently played or imported, in most-recent-first order (max 10).
  /// Used to determine the display priority of tiles in WPUI Library → Albums.
  /// Phase 97: @AppStorage + @ObservationIgnored bridge (replaces manual UserDefaults read/write).
  @ObservationIgnored @AppStorage(wrappedValue: [], "MadTunes.WPUI.recentAlbumKeys")
  private var _recentAlbumKeys: [String]

  /// Phase 97: @AppStorage + @ObservationIgnored bridge (fixes @Observable didSet not firing).
  @ObservationIgnored @AppStorage(wrappedValue: .cobalt, "MadTunes.wpAccentColor")
  private var _wpAccentColor: WPAccentColor

  /// Tracks the last known `isImporting` for edge detection.
  private var _previousIsImporting = false

  /// Phase 96: Record album play activity when the current track changes.
  private func observeCurrentTrackForActivity() {
    withObservationTracking {
      _ = self.mainVM?.player.currentTrack?.id
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if let track = self.mainVM?.player.currentTrack {
          self.recordAlbumActivity(title: track.albumTitle, artist: track.albumArtist)
        }
        self.observeCurrentTrackForActivity()
      }
    }
  }

  /// Phase 96: Record newly imported albums when import finishes.
  private func observeImportCompletion() {
    withObservationTracking {
      _ = self.mainVM?.library.isImporting
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        let isImporting = self.mainVM?.library.isImporting ?? false
        let wasImporting = self._previousIsImporting
        self._previousIsImporting = isImporting
        if wasImporting, !isImporting, let mainVM = self.mainVM {
          self.recordNewlyImportedAlbums(from: mainVM.gridVM.currentAlbumsDisplayed)
        }
        self.observeImportCompletion()
      }
    }
  }
}
