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

  /// Currently displayed Panorama section.
  var currentSection: PanoramaSection = .library

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
  var isTrackInfoPresented = false

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

  /// Standalone playlist creation (from Playlists section + button).
  var isCreatePlaylistAlertPresented = false
  var createPlaylistName = ""

  var wpAccentColor: WPAccentColor = {
    if let raw = UserDefaults.standard.string(forKey: "MadTunes.wpAccentColor"),
       let accent = WPAccentColor(rawValue: raw) {
      return accent
    }
    return .cobalt
  }() {
    didSet {
      UserDefaults.standard.set(wpAccentColor.rawValue, forKey: "MadTunes.wpAccentColor")
    }
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
        tracks: tracks,
        artworkData: mainVM.library.artworkCache[
          mainVM.library.albumKey(title: first.albumTitle, artist: first.albumArtist)
        ]
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

  /// Determines tile size based on album position and properties.
  func tileSizeForAlbum(_ album: Album, index: Int) -> TileSize {
    if index == 0 { return .large }
    if let mainVM, mainVM.library.playlists.count > 1,
       let favorites = mainVM.library.playlists.dropFirst().first,
       favorites.trackIDs.contains(where: { trackID in
         album.allTrackIDsSet.contains(trackID)
       }), index < 5 {
      return .medium
    }
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

  /// Phase 78: Create a new empty playlist from the Playlists section.
  func commitCreatePlaylist() {
    guard let mainVM else { return }
    let name = createPlaylistName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    let existingNames = Set(mainVM.library.playlists.dropFirst(2).map(\.name))
    guard !existingNames.contains(name) else { return }
    mainVM.library.addPlaylist(name: name)
    createPlaylistName = ""
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
}
