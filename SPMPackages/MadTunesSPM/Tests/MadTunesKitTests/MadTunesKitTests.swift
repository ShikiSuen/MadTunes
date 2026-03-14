// (c) 2026 and onwards Shiki Suen (AGPL-3.0-or-later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
@testable import MadTunesKit
import Testing

// MARK: - Test Helpers

private let dummyURL = URL(fileURLWithPath: "/tmp/test.mp3")

private func makeTrack(
  title: String = "Song",
  artist: String = "Artist",
  albumTitle: String = "Album",
  albumArtist: String = "",
  trackNumber: Int = 1,
  discNumber: Int = 1,
  duration: TimeInterval = 180,
  genre: String = "Rock",
  year: Int? = 2024
)
  -> Track {
  Track(
    fileURL: dummyURL,
    title: title,
    artist: artist,
    albumTitle: albumTitle,
    albumArtist: albumArtist.isEmpty ? artist : albumArtist,
    trackNumber: trackNumber,
    discNumber: discNumber,
    duration: duration,
    genre: genre,
    year: year
  )
}

// MARK: - AlbumTests

@Suite("Album")
struct AlbumTests {
  @Test("Album.init sorts tracks by disc, track number, title")
  func albumSortsTracksOnInit() {
    let t1 = makeTrack(title: "C", trackNumber: 3, discNumber: 1)
    let t2 = makeTrack(title: "A", trackNumber: 1, discNumber: 1)
    let t3 = makeTrack(title: "B", trackNumber: 2, discNumber: 1)

    let album = Album(title: "Test", artist: "Artist", tracks: [t1, t2, t3])

    #expect(album.tracks.map(\.title) == ["A", "B", "C"])
  }

  @Test("Album.init sorts by disc first then track number")
  func albumSortsByDiscFirst() {
    let d2t1 = makeTrack(title: "D2T1", trackNumber: 1, discNumber: 2)
    let d1t2 = makeTrack(title: "D1T2", trackNumber: 2, discNumber: 1)
    let d1t1 = makeTrack(title: "D1T1", trackNumber: 1, discNumber: 1)

    let album = Album(title: "Test", artist: "Artist", tracks: [d2t1, d1t2, d1t1])

    #expect(album.tracks.map(\.title) == ["D1T1", "D1T2", "D2T1"])
  }

  @Test("Album.totalDuration sums track durations")
  func totalDuration() {
    let t1 = makeTrack(duration: 120)
    let t2 = makeTrack(duration: 180)
    let album = Album(title: "A", artist: "B", tracks: [t1, t2])

    #expect(album.totalDuration == 300)
  }

  @Test("Album.showDiscNumber is true only when multiple disc numbers exist")
  func showDiscNumber() {
    let singleDisc = Album(
      title: "A", artist: "B",
      tracks: [makeTrack(discNumber: 1), makeTrack(discNumber: 1)]
    )
    #expect(!singleDisc.showDiscNumber)

    let multiDisc = Album(
      title: "A", artist: "B",
      tracks: [makeTrack(discNumber: 1), makeTrack(discNumber: 2)]
    )
    #expect(multiDisc.showDiscNumber)
  }

  @Test("Album.allTrackArtistsSameAsAlbumArtist")
  func allTrackArtistsSame() {
    let same = Album(
      title: "A", artist: "Band",
      tracks: [makeTrack(artist: "Band"), makeTrack(artist: "Band")]
    )
    #expect(same.allTrackArtistsSameAsAlbumArtist)

    let different = Album(
      title: "A", artist: "Band",
      tracks: [makeTrack(artist: "Band"), makeTrack(artist: "Guest")]
    )
    #expect(!different.allTrackArtistsSameAsAlbumArtist)
  }
}

// MARK: - SearchTokenTests

@Suite("SearchTokens")
struct SearchTokenTests {
  @Test("Empty string produces no tokens")
  func emptyString() {
    #expect(searchTokens(from: "").isEmpty)
  }

  @Test("Single word produces one token lowercased")
  func singleWord() {
    let tokens = searchTokens(from: "Hello")
    #expect(tokens.contains("hello"))
  }

  @Test("Multiple words produce multiple tokens")
  func multipleWords() {
    let tokens = searchTokens(from: "Pink Floyd")
    #expect(tokens.contains("pink"))
    #expect(tokens.contains("floyd"))
  }
}

// MARK: - TrackMatchesSearchTests

@Suite("TrackMatchesSearch")
struct TrackMatchesSearchTests {
  let vm = MadTunesViewModel.shared

  @Test("Empty tokens match any track")
  func emptyTokensMatch() {
    let track = makeTrack(title: "Anything")
    #expect(vm.trackMatchesSearch(track, tokens: [], mode: .either))
  }

  @Test("Track title mode matches title only")
  func trackTitleMode() {
    let track = makeTrack(title: "Bohemian Rhapsody", artist: "Queen", albumTitle: "Night at the Opera")
    let tokens = searchTokens(from: "Bohemian")
    #expect(vm.trackMatchesSearch(track, tokens: tokens, mode: .trackTitle))
    #expect(!vm.trackMatchesSearch(track, tokens: searchTokens(from: "Queen"), mode: .trackTitle))
  }

  @Test("Album title mode matches album title only")
  func albumTitleMode() {
    let track = makeTrack(title: "Song", artist: "Band", albumTitle: "Greatest Hits")
    let tokens = searchTokens(from: "Greatest")
    #expect(vm.trackMatchesSearch(track, tokens: tokens, mode: .albumTitle))
    #expect(!vm.trackMatchesSearch(track, tokens: searchTokens(from: "Song"), mode: .albumTitle))
  }

  @Test("Artist mode matches artist or albumArtist")
  func artistMode() {
    let track = makeTrack(artist: "Vocalist", albumArtist: "Full Band")
    let tokensArtist = searchTokens(from: "Vocalist")
    let tokensAlbumArtist = searchTokens(from: "Full Band")
    #expect(vm.trackMatchesSearch(track, tokens: tokensArtist, mode: .artist))
    #expect(vm.trackMatchesSearch(track, tokens: tokensAlbumArtist, mode: .artist))
  }

  @Test("Either mode matches across all fields")
  func eitherMode() {
    let track = makeTrack(title: "Yesterday", artist: "Beatles", albumTitle: "Help")
    #expect(vm.trackMatchesSearch(track, tokens: searchTokens(from: "Yesterday"), mode: .either))
    #expect(vm.trackMatchesSearch(track, tokens: searchTokens(from: "Beatles"), mode: .either))
    #expect(vm.trackMatchesSearch(track, tokens: searchTokens(from: "Help"), mode: .either))
  }

  @Test("Multi-token search requires all tokens to match (AND logic)")
  func multiTokenAnd() {
    let track = makeTrack(title: "Hotel California", artist: "Eagles")
    // Both tokens in different fields — should match in .either mode
    #expect(vm.trackMatchesSearch(track, tokens: searchTokens(from: "Hotel Eagles"), mode: .either))
    // Token "Missing" not found in any field
    #expect(!vm.trackMatchesSearch(track, tokens: searchTokens(from: "Hotel Missing"), mode: .either))
  }
}

// MARK: - TrackPassesAllFiltersTests

@Suite("TrackPassesAllFilters")
struct TrackPassesAllFiltersTests {
  let vm = MadTunesViewModel.shared

  @Test("No column browser filters: delegates to search")
  func noColumnBrowser() {
    let track = makeTrack(title: "Found", genre: "Rock")
    // Clear any column browser state
    vm.resetColumnBrowserFilters()
    #expect(vm.trackPassesAllFilters(track, tokens: searchTokens(from: "Found"), mode: .either))
  }

  @Test("Genre column browser rejects non-matching genre")
  func genreColumnBrowserFilter() {
    vm.resetColumnBrowserFilters()
    vm.columnBrowserSelectedGenres = ["Jazz"]
    let rock = makeTrack(genre: "Rock")
    #expect(!vm.trackPassesAllFilters(rock, tokens: [], mode: .either))
    let jazz = makeTrack(genre: "Jazz")
    #expect(vm.trackPassesAllFilters(jazz, tokens: [], mode: .either))
    // Cleanup
    vm.resetColumnBrowserFilters()
  }
}

// MARK: - MockMusicLibraryPlaylistTests

@Suite("MockMusicLibrary Playlists")
struct MockMusicLibraryPlaylistTests {
  @Test("addPlaylist creates a new playlist")
  func addPlaylist() {
    let mock = MockMusicLibrary()
    mock.addPlaylist(name: "My Playlist")
    #expect(mock.playlists.count == 3) // 2 system + 1 new
    #expect(mock.playlists.last?.name == "My Playlist")
  }

  @Test("addTracks adds track IDs to playlist")
  func addTracks() {
    let mock = MockMusicLibrary()
    let t1 = makeTrack(title: "A")
    let t2 = makeTrack(title: "B")
    mock.setTracks([t1, t2])
    mock.addPlaylist(name: "Test")
    let pid = mock.playlists.last!.id
    mock.addTracks([t1.id, t2.id], toPlaylist: pid)
    #expect(mock.playlists.last!.trackIDs.count == 2)
  }

  @Test("removeTracks removes from library and playlists")
  func removeTracks() {
    let mock = MockMusicLibrary()
    let t1 = makeTrack(title: "Keep")
    let t2 = makeTrack(title: "Remove")
    mock.setTracks([t1, t2])
    mock.addPlaylist(name: "P")
    let pid = mock.playlists.last!.id
    mock.addTracks([t1.id, t2.id], toPlaylist: pid)

    mock.removeTracks(ids: [t2.id])

    #expect(mock.tracks.count == 1)
    #expect(mock.tracks.first?.title == "Keep")
    #expect(mock.playlists.last!.trackIDs == [t1.id])
  }

  @Test("moveTracks reorders within playlist")
  func moveTracks() {
    let mock = MockMusicLibrary()
    let t1 = makeTrack(title: "A")
    let t2 = makeTrack(title: "B")
    let t3 = makeTrack(title: "C")
    mock.setTracks([t1, t2, t3])
    mock.addPlaylist(name: "P")
    let pid = mock.playlists.last!.id
    mock.addTracks([t1.id, t2.id, t3.id], toPlaylist: pid)

    // Move t3 to index 0 (before t1)
    mock.moveTracks([t3.id], inPlaylist: pid, toIndex: 0)

    #expect(mock.playlists.last!.trackIDs == [t3.id, t1.id, t2.id])
  }

  @Test("Favorites toggle works")
  func favorites() {
    let mock = MockMusicLibrary()
    let t = makeTrack()
    mock.setTracks([t])

    #expect(!mock.isFavorited(t.id))
    mock.toggleFavorite(trackIDs: [t.id])
    #expect(mock.isFavorited(t.id))
    mock.toggleFavorite(trackIDs: [t.id])
    #expect(!mock.isFavorited(t.id))
  }
}

// MARK: - AlbumTableViewModelTests

@Suite("AlbumTableViewModel")
struct AlbumTableViewModelTests {
  @Test("Column visibility defaults match TableColumnType.isDefaultVisible")
  func columnVisibilityDefaults() {
    // Clear persisted state so fresh defaults apply.
    UserDefaults.standard.removeObject(forKey: TableColumnType.userDefaultsKey)
    let tableVM = AlbumTableViewModel()
    for column in TableColumnType.allCases {
      #expect(tableVM.isColumnVisible(column) == column.isDefaultVisible)
    }
  }

  @Test("toggleColumnVisibility flips visibility")
  func toggleColumn() {
    UserDefaults.standard.removeObject(forKey: TableColumnType.userDefaultsKey)
    let tableVM = AlbumTableViewModel()
    let col = TableColumnType.genre // default visible
    #expect(tableVM.isColumnVisible(col))
    tableVM.toggleColumnVisibility(col)
    #expect(!tableVM.isColumnVisible(col))
  }

  @Test("Hiding all hidable columns still leaves playingIndicator visible")
  func cannotHideAll() {
    UserDefaults.standard.removeObject(forKey: TableColumnType.userDefaultsKey)
    let tableVM = AlbumTableViewModel()
    // Hide every hidable column
    for col in TableColumnType.allCases where col.isHidable {
      if tableVM.isColumnVisible(col) {
        tableVM.toggleColumnVisibility(col)
      }
    }
    // PlayingIndicator is always visible (not hidable)
    #expect(tableVM.isColumnVisible(.playingIndicator))
    // visibleColumns should contain at least playingIndicator
    #expect(!tableVM.visibleColumns.isEmpty)
  }

  @Test("columnWidth returns default when no custom width set")
  func columnWidthDefault() {
    UserDefaults.standard.removeObject(forKey: TableColumnType.columnWidthsKey)
    let tableVM = AlbumTableViewModel()
    for col in TableColumnType.allCases {
      #expect(tableVM.columnWidth(for: col) == col.defaultWidth)
    }
  }
}

// MARK: - AlbumGridViewModelTests

@Suite("AlbumGridViewModel")
struct AlbumGridViewModelTests {
  @Test("scheduleDisplayedAlbumsUpdate populates displayedAlbums")
  func displayedAlbumsUpdate() async throws {
    let gridVM = AlbumGridViewModel()
    let albums = [
      Album(title: "A", artist: "X", tracks: [makeTrack(albumTitle: "A", albumArtist: "X")]),
      Album(title: "B", artist: "Y", tracks: [makeTrack(albumTitle: "B", albumArtist: "Y")]),
    ]
    gridVM.scheduleDisplayedAlbumsUpdate(to: albums)
    // Allow the Task to complete
    try await Task.sleep(for: .milliseconds(100))
    #expect(gridVM.displayedAlbums.count == 2)
  }

  @Test("selectionRect returns nil when no drag")
  func selectionRectNil() {
    let gridVM = AlbumGridViewModel()
    #expect(gridVM.selectionRect == nil)
  }

  @Test("selectionRect computes normalized rect")
  func selectionRectComputed() {
    let gridVM = AlbumGridViewModel()
    gridVM.dragOrigin = CGPoint(x: 100, y: 200)
    gridVM.dragCurrent = CGPoint(x: 50, y: 150)
    let rect = gridVM.selectionRect!
    #expect(rect.origin.x == 50)
    #expect(rect.origin.y == 150)
    #expect(rect.width == 50)
    #expect(rect.height == 50)
  }

  @Test("commitNewPlaylistAlert creates playlist with tracks")
  func commitNewPlaylist() {
    let gridVM = AlbumGridViewModel()
    let mock = MockMusicLibrary()
    let t1 = makeTrack(title: "X")
    mock.setTracks([t1])

    gridVM.trackIDsForNewPlaylist = [t1.id]
    gridVM.newPlaylistName = "Test PL"
    gridVM.commitNewPlaylistAlert(library: mock)

    #expect(mock.playlists.count == 3)
    #expect(mock.playlists.last?.name == "Test PL")
    #expect(mock.playlists.last?.trackIDs == [t1.id])
    #expect(gridVM.trackIDsForNewPlaylist.isEmpty)
  }
}
