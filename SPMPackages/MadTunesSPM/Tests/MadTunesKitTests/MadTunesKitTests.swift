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
    let playlistIdx = mock.playlists.count - 1
    let pid = mock.playlists[playlistIdx].id
    // Set trackIDs directly to guarantee deterministic order (Set iteration is unordered).
    mock.playlists[playlistIdx].trackIDs = [t1.id, t2.id, t3.id]

    // Move t3 to index 0 (before t1)
    mock.moveTracks([t3.id], inPlaylist: pid, toIndex: 0)

    #expect(mock.playlists[playlistIdx].trackIDs == [t3.id, t1.id, t2.id])
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

// MARK: - Phase130RegressionTests

@Suite("Phase 130 Regressions")
struct Phase130RegressionTests {
  @Test("albums(for:) uses playlist-scoped album IDs")
  func playlistScopedAlbumIDs() {
    let library = MusicLibrary()
    let t1 = makeTrack(title: "D", albumTitle: "C", albumArtist: "Band", trackNumber: 1)
    let t2 = makeTrack(title: "E", albumTitle: "C", albumArtist: "Band", trackNumber: 2)

    library.tracks = [t1, t2]
    library.playlists[0].trackIDs = [t1.id, t2.id]

    library.addPlaylist(name: "B")
    guard let playlistB = library.playlists.last else {
      Issue.record("Failed to create static playlist B")
      return
    }
    library.addTracks([t1.id], toPlaylist: playlistB.id)

    guard let updatedPlaylistB = library.playlists.first(where: { $0.id == playlistB.id }) else {
      Issue.record("Failed to fetch updated playlist B")
      return
    }

    let allMusicAlbum = library.albums(for: library.playlists[0]).first
    let playlistBAlbum = library.albums(for: updatedPlaylistB).first

    #expect(allMusicAlbum != nil)
    #expect(playlistBAlbum != nil)
    #expect(allMusicAlbum?.tracks.count == 2)
    #expect(playlistBAlbum?.tracks.count == 1)
    #expect(allMusicAlbum?.id != playlistBAlbum?.id)
  }

  @Test("onPlaylistSwitched clears display/search buffers")
  func playlistSwitchClearsDisplayBuffers() {
    let vm = MadTunesViewModel.shared

    vm.searchText = "phase130"
    vm.isSearching = true
    vm.displayedTracksCache = [makeTrack(title: "CachedTrack")]

    let cachedAlbum = Album(
      title: "CachedAlbum",
      artist: "CachedArtist",
      tracks: [makeTrack(title: "CachedTrack")]
    )
    vm.gridVM.displayedAlbumsCache = [cachedAlbum]
    vm.gridVM.displayedAlbums = [cachedAlbum]
    vm.tableVM.displayedTracks = [makeTrack(title: "CachedTableTrack")]

    vm.onPlaylistSwitched()

    #expect(!vm.isSearching)
    #expect(vm.displayedTracksCache.isEmpty)
    #expect(vm.gridVM.displayedAlbumsCache.isEmpty)
    #expect(vm.gridVM.displayedAlbums.isEmpty)
    #expect(vm.tableVM.displayedTracks.isEmpty)
  }
}

// MARK: - Phase135RegressionTests

@Suite("Phase 135 Regressions")
struct Phase135RegressionTests {
  @Test("dynamic playlist with folder datasource resolves matched tracks")
  func dynamicPlaylistWithFolderDatasource() throws {
    let library = MusicLibrary()

    let folderPlaylist = Playlist(name: "HoYo Folder", kind: .folderList)
    let matchTrack = makeTrack(title: "A", artist: "HoYo")
    let nonMatchTrack = makeTrack(title: "B", artist: "Other")

    library.playlists.append(folderPlaylist)
    library.folderPlaylistTracks[folderPlaylist.id] = [matchTrack, nonMatchTrack]

    let predicate = PlaylistPredicate.single(
      PlaylistCondition(field: .artist, comparator: .contains, value: .string("HoYo"))
    )
    let predicateData = try JSONEncoder().encode(predicate)

    let dynamicPlaylist = Playlist(
      name: "Filtered HoYo",
      kind: .dynamicList,
      predicateData: predicateData,
      sourceFolderPlaylistIDSet: [folderPlaylist.id]
    )
    library.playlists.append(dynamicPlaylist)

    library.evaluateDynamicPlaylist(id: dynamicPlaylist.id)

    guard let evaluatedPlaylist = library.playlists.first(where: { $0.id == dynamicPlaylist.id }) else {
      Issue.record("Failed to find evaluated dynamic playlist")
      return
    }

    #expect(evaluatedPlaylist.trackIDs == [matchTrack.id])
    #expect(library.tracks(for: evaluatedPlaylist).map(\.id) == [matchTrack.id])
  }

  @Test("duplicatePlaylist preserves sourceFolderPlaylistIDSet")
  func duplicatePreservesSourceFolder() throws {
    let library = MusicLibrary()

    let folderPlaylist = Playlist(name: "Source Folder", kind: .folderList)
    library.playlists.append(folderPlaylist)
    library.folderPlaylistTracks[folderPlaylist.id] = [makeTrack(title: "X")]

    let predicate = PlaylistPredicate.single(
      PlaylistCondition(field: .artist, comparator: .contains, value: .string("Any"))
    )
    let predicateData = try JSONEncoder().encode(predicate)

    let dynamic = Playlist(
      name: "BoundDynamic",
      kind: .dynamicList,
      predicateData: predicateData,
      sourceFolderPlaylistIDSet: [folderPlaylist.id]
    )
    library.playlists.append(dynamic)

    guard let dupID = library.duplicatePlaylist(id: dynamic.id),
          let dup = library.playlists.first(where: { $0.id == dupID })
    else {
      Issue.record("duplicatePlaylist returned nil")
      return
    }

    #expect(dup.sourceFolderPlaylistIDSet == [folderPlaylist.id])
    #expect(dup.predicateData == predicateData)
    #expect(dup.kind == .dynamicList)
    #expect(dup.id != dynamic.id)
  }

  @Test("toggleSourceFolderPlaylist adds and removes folder datasource")
  func toggleSourceAddsAndRemoves() throws {
    let library = MusicLibrary()

    let libTrack = makeTrack(title: "LibSong", artist: "CommonArtist")
    library.tracks = [libTrack]

    let folderPlaylist = Playlist(name: "Folder", kind: .folderList)
    let folderTrack = makeTrack(title: "FolderSong", artist: "CommonArtist")
    library.playlists.append(folderPlaylist)
    library.folderPlaylistTracks[folderPlaylist.id] = [folderTrack]

    let predicate = PlaylistPredicate.single(
      PlaylistCondition(field: .artist, comparator: .contains, value: .string("CommonArtist"))
    )
    let predicateData = try JSONEncoder().encode(predicate)

    let dynamic = Playlist(name: "Dynamic", kind: .dynamicList, predicateData: predicateData)
    library.playlists.append(dynamic)
    library.evaluateDynamicPlaylist(id: dynamic.id)

    // Should match main library track.
    let beforeToggle = library.playlists.first(where: { $0.id == dynamic.id })!
    #expect(beforeToggle.trackIDs == [libTrack.id])

    // Toggle folder datasource on.
    library.toggleSourceFolderPlaylist(playlistID: dynamic.id, folderPlaylistID: folderPlaylist.id)

    let afterToggleOn = library.playlists.first(where: { $0.id == dynamic.id })!
    #expect(afterToggleOn.sourceFolderPlaylistIDSet.contains(folderPlaylist.id))
    #expect(afterToggleOn.trackIDs == [folderTrack.id])
    #expect(library.tracks(for: afterToggleOn).map(\.id) == [folderTrack.id])

    // Toggle folder datasource off.
    library.toggleSourceFolderPlaylist(playlistID: dynamic.id, folderPlaylistID: folderPlaylist.id)

    let afterToggleOff = library.playlists.first(where: { $0.id == dynamic.id })!
    #expect(afterToggleOff.sourceFolderPlaylistIDSet.isEmpty)
    #expect(afterToggleOff.trackIDs == [libTrack.id])
  }

  @Test("clearAllSourceFolderPlaylists reverts to library-wide evaluation")
  func clearAllRevertsToLibrary() throws {
    let library = MusicLibrary()

    let libTrack = makeTrack(title: "LibOnly", artist: "Band")
    library.tracks = [libTrack]

    let folderPlaylist = Playlist(name: "Folder", kind: .folderList)
    let folderTrack = makeTrack(title: "FolderOnly", artist: "Band")
    library.playlists.append(folderPlaylist)
    library.folderPlaylistTracks[folderPlaylist.id] = [folderTrack]

    let predicate = PlaylistPredicate.single(
      PlaylistCondition(field: .artist, comparator: .contains, value: .string("Band"))
    )
    let predicateData = try JSONEncoder().encode(predicate)

    let dynamic = Playlist(
      name: "Dynamic",
      kind: .dynamicList,
      predicateData: predicateData,
      sourceFolderPlaylistIDSet: [folderPlaylist.id]
    )
    library.playlists.append(dynamic)
    library.evaluateDynamicPlaylist(id: dynamic.id)

    // Currently bound to folder.
    let bound = library.playlists.first(where: { $0.id == dynamic.id })!
    #expect(bound.trackIDs == [folderTrack.id])

    // Revert to full library.
    library.clearAllSourceFolderPlaylists(playlistID: dynamic.id)

    let reverted = library.playlists.first(where: { $0.id == dynamic.id })!
    #expect(reverted.sourceFolderPlaylistIDSet.isEmpty)
    #expect(reverted.trackIDs == [libTrack.id])
    #expect(library.tracks(for: reverted).map(\.id) == [libTrack.id])
  }

  @Test("removeFolderPlaylist removes ID from sourceFolderPlaylistIDSet")
  func removeFolderClearsDynamicReferences() throws {
    let library = MusicLibrary()

    let libTrack = makeTrack(title: "LibTrack", artist: "Shared")
    library.tracks = [libTrack]

    let folderPlaylist = Playlist(name: "WillDelete", kind: .folderList)
    let folderTrack = makeTrack(title: "FolderTrack", artist: "Shared")
    library.playlists.append(folderPlaylist)
    library.folderPlaylistTracks[folderPlaylist.id] = [folderTrack]

    let predicate = PlaylistPredicate.single(
      PlaylistCondition(field: .artist, comparator: .contains, value: .string("Shared"))
    )
    let predicateData = try JSONEncoder().encode(predicate)

    let dynamic = Playlist(
      name: "Dependent",
      kind: .dynamicList,
      predicateData: predicateData,
      sourceFolderPlaylistIDSet: [folderPlaylist.id]
    )
    library.playlists.append(dynamic)
    library.evaluateDynamicPlaylist(id: dynamic.id)

    // Sanity: bound to folder.
    #expect(library.playlists.first(where: { $0.id == dynamic.id })!.trackIDs == [folderTrack.id])

    // Delete the folder playlist.
    library.removeFolderPlaylist(id: folderPlaylist.id)

    // Dynamic playlist should have source removed and be re-evaluated against library.
    let afterDelete = library.playlists.first(where: { $0.id == dynamic.id })!
    #expect(afterDelete.sourceFolderPlaylistIDSet.isEmpty)
    #expect(afterDelete.trackIDs == [libTrack.id])
  }

  @Test("multiple folder datasources aggregate tracks for evaluation")
  func multipleFolderDatasources() throws {
    let library = MusicLibrary()

    let folder1 = Playlist(name: "Folder1", kind: .folderList)
    let folder2 = Playlist(name: "Folder2", kind: .folderList)
    let track1 = makeTrack(title: "Song1", artist: "TargetArtist")
    let track2 = makeTrack(title: "Song2", artist: "TargetArtist")
    let track3 = makeTrack(title: "Song3", artist: "Other")

    library.playlists.append(contentsOf: [folder1, folder2])
    library.folderPlaylistTracks[folder1.id] = [track1, track3]
    library.folderPlaylistTracks[folder2.id] = [track2]

    let predicate = PlaylistPredicate.single(
      PlaylistCondition(field: .artist, comparator: .contains, value: .string("TargetArtist"))
    )
    let predicateData = try JSONEncoder().encode(predicate)

    let dynamic = Playlist(
      name: "MultiSource",
      kind: .dynamicList,
      predicateData: predicateData,
      sourceFolderPlaylistIDSet: [folder1.id, folder2.id]
    )
    library.playlists.append(dynamic)
    library.evaluateDynamicPlaylist(id: dynamic.id)

    let evaluated = library.playlists.first(where: { $0.id == dynamic.id })!
    #expect(Set(evaluated.trackIDs) == [track1.id, track2.id])

    let resolved = library.tracks(for: evaluated)
    #expect(Set(resolved.map(\.id)) == [track1.id, track2.id])
  }

  @Test("predicate editor matched count respects folder datasource")
  func predicateEditorCountRespectsFolderDatasource() throws {
    let library = MusicLibrary()

    // These should be ignored because dynamic playlist is bound to folder datasource.
    let libMatch1 = makeTrack(title: "Lib1", artist: "Target")
    let libMatch2 = makeTrack(title: "Lib2", artist: "Target")
    library.tracks = [libMatch1, libMatch2]

    let folder = Playlist(name: "Folder", kind: .folderList)
    let folderMatch = makeTrack(title: "FolderMatch", artist: "Target")
    let folderMiss = makeTrack(title: "FolderMiss", artist: "Other")
    library.playlists.append(folder)
    library.folderPlaylistTracks[folder.id] = [folderMatch, folderMiss]

    let predicate = PlaylistPredicate.single(
      PlaylistCondition(field: .artist, comparator: .contains, value: .string("Target"))
    )
    let predicateData = try JSONEncoder().encode(predicate)

    let dynamic = Playlist(
      name: "Dynamic",
      kind: .dynamicList,
      predicateData: predicateData,
      sourceFolderPlaylistIDSet: [folder.id]
    )
    library.playlists.append(dynamic)

    let vm = PredicateEditorViewModel(playlist: dynamic, library: library)
    #expect(vm.matchingTrackCount() == 1)
  }

  @Test("predicate editor matched count aggregates all selected datasources")
  func predicateEditorCountAggregatesSelectedDatasources() throws {
    let library = MusicLibrary()

    // Should not affect count when datasource set is non-empty.
    library.tracks = [makeTrack(title: "Lib", artist: "Target")]

    let folder1 = Playlist(name: "Folder1", kind: .folderList)
    let folder2 = Playlist(name: "Folder2", kind: .folderList)
    let folder1Match = makeTrack(title: "F1", artist: "Target")
    let folder2Match = makeTrack(title: "F2", artist: "Target")

    library.playlists.append(contentsOf: [folder1, folder2])
    library.folderPlaylistTracks[folder1.id] = [folder1Match]
    library.folderPlaylistTracks[folder2.id] = [folder2Match]

    let predicate = PlaylistPredicate.single(
      PlaylistCondition(field: .artist, comparator: .contains, value: .string("Target"))
    )
    let predicateData = try JSONEncoder().encode(predicate)

    let dynamic = Playlist(
      name: "Dynamic",
      kind: .dynamicList,
      predicateData: predicateData,
      sourceFolderPlaylistIDSet: [folder1.id, folder2.id]
    )
    library.playlists.append(dynamic)

    let vm = PredicateEditorViewModel(playlist: dynamic, library: library)
    #expect(vm.matchingTrackCount() == 2)
  }

  @Test("folderPlaylistsAsDataSources returns only folder playlists")
  func folderPlaylistsAsDataSourcesFilter() {
    let library = MusicLibrary()

    let folder1 = Playlist(name: "Folder1", kind: .folderList)
    let folder2 = Playlist(name: "Folder2", kind: .folderList)
    let staticPL = Playlist(name: "Static", kind: .staticList)
    let dynamicPL = Playlist(name: "Dynamic", kind: .dynamicList)

    library.playlists.append(contentsOf: [folder1, folder2, staticPL, dynamicPL])

    let sources = library.folderPlaylistsAsDataSources()
    #expect(sources.count == 2)
    #expect(Set(sources.map(\.id)) == [folder1.id, folder2.id])
  }

  @Test("dynamic playlist icon changes with sourceFolderPlaylistIDSet")
  func iconReflectsDataSource() {
    let unboundDynamic = Playlist(name: "Unbound", kind: .dynamicList)
    #expect(unboundDynamic.icon4SFSymbols() == "gearshape.2")

    let boundDynamic = Playlist(
      name: "Bound",
      kind: .dynamicList,
      sourceFolderPlaylistIDSet: [UUID()]
    )
    #expect(boundDynamic.icon4SFSymbols() == "folder.fill.badge.gearshape")
  }
}

// MARK: - Phase96ObservationTests

@Suite("Phase 96: ViewModel Observation Migration")
struct Phase96ObservationTests {
  @Test("onPlaylistSwitched clears selectedTrackIDs")
  func playlistSwitchClearsTrackSelection() {
    let vm = MadTunesViewModel.shared
    // Setup: add some tracks to selection.
    let t1 = makeTrack(title: "T1")
    vm.selectedTrackIDs = [t1.id]
    #expect(!vm.selectedTrackIDs.isEmpty)

    vm.onPlaylistSwitched()

    #expect(vm.selectedTrackIDs.isEmpty)
  }

  @Test("onPlaylistSwitched clears highlightedAlbumIDs")
  func playlistSwitchClearsAlbumHighlights() {
    let vm = MadTunesViewModel.shared
    let albumID = UUID()
    vm.gridVM.highlightedAlbumIDs = [albumID]

    vm.onPlaylistSwitched()

    #expect(vm.gridVM.highlightedAlbumIDs.isEmpty)
  }

  @Test("onPlaylistSwitched clears expandedAlbumID")
  func playlistSwitchClearsExpandedAlbum() {
    let vm = MadTunesViewModel.shared
    vm.gridVM.expandedAlbumID = UUID()

    vm.onPlaylistSwitched()

    #expect(vm.gridVM.expandedAlbumID == nil)
  }

  @Test("onPlaylistSwitched clears table selection anchors")
  func playlistSwitchClearsTableAnchors() {
    let vm = MadTunesViewModel.shared
    vm.tableVM.tableSelectionAnchorID = UUID()
    vm.tableVM.tableSelectionCursorID = UUID()

    vm.onPlaylistSwitched()

    #expect(vm.tableVM.tableSelectionAnchorID == nil)
    #expect(vm.tableVM.tableSelectionCursorID == nil)
  }

  @Test("onPlaylistSwitched deactivates table edit mode")
  func playlistSwitchClearsEditMode() {
    let vm = MadTunesViewModel.shared
    vm.tableVM.isEditModeActive = true

    vm.onPlaylistSwitched()

    #expect(!vm.tableVM.isEditModeActive)
  }

  @Test("onPlaylistSwitched resets column browser filters")
  func playlistSwitchResetsFilters() {
    let vm = MadTunesViewModel.shared
    vm.columnBrowserSelectedGenres = ["Rock"]
    vm.columnBrowserSelectedAlbumArtists = ["Artist"]

    vm.onPlaylistSwitched()

    #expect(vm.columnBrowserSelectedGenres.isEmpty)
    #expect(vm.columnBrowserSelectedAlbumArtists.isEmpty)
  }

  @Test("onPlaylistSwitched clears search text when non-empty")
  func playlistSwitchClearsSearch() {
    let vm = MadTunesViewModel.shared
    vm.searchText = "test query"

    vm.onPlaylistSwitched()

    #expect(vm.searchText.isEmpty)
  }

  @Test("onPlaylistSwitched clears grid selection anchors")
  func playlistSwitchClearsGridAnchors() {
    let vm = MadTunesViewModel.shared
    vm.gridVM.albumSelectionFixedAnchorID = UUID()
    vm.gridVM.albumSelectionCursorID = UUID()

    vm.onPlaylistSwitched()

    #expect(vm.gridVM.albumSelectionFixedAnchorID == nil)
    #expect(vm.gridVM.albumSelectionCursorID == nil)
  }
}

// MARK: - PlaylistPredicateTests

@Suite("PlaylistPredicate")
struct PlaylistPredicateTests {
  // MARK: Internal

  // MARK: - String comparators

  @Test("contains: case-insensitive substring match")
  func stringContains() {
    let cond = PlaylistCondition(field: .title, comparator: .contains, value: .string("highway"))
    #expect(cond.evaluate(track: rockTrack))
    #expect(!cond.evaluate(track: jazzTrack))
  }

  @Test("notContains: rejects substring match")
  func stringNotContains() {
    let cond = PlaylistCondition(field: .title, comparator: .notContains, value: .string("highway"))
    #expect(!cond.evaluate(track: rockTrack))
    #expect(cond.evaluate(track: jazzTrack))
  }

  @Test("equals: full string match case-insensitive")
  func stringEquals() {
    let cond = PlaylistCondition(field: .artist, comparator: .equals, value: .string("deep purple"))
    #expect(cond.evaluate(track: rockTrack))
    #expect(!cond.evaluate(track: jazzTrack))
  }

  @Test("notEquals: rejects full string match")
  func stringNotEquals() {
    let cond = PlaylistCondition(field: .artist, comparator: .notEquals, value: .string("deep purple"))
    #expect(!cond.evaluate(track: rockTrack))
    #expect(cond.evaluate(track: jazzTrack))
  }

  @Test("startsWith: prefix match")
  func stringStartsWith() {
    let cond = PlaylistCondition(field: .title, comparator: .startsWith, value: .string("high"))
    #expect(cond.evaluate(track: rockTrack))
    #expect(!cond.evaluate(track: jazzTrack))
  }

  @Test("endsWith: suffix match")
  func stringEndsWith() {
    let cond = PlaylistCondition(field: .title, comparator: .endsWith, value: .string("star"))
    #expect(cond.evaluate(track: rockTrack))
    #expect(!cond.evaluate(track: jazzTrack))
  }

  // MARK: - Integer comparators

  @Test("year equals")
  func intEquals() {
    let cond = PlaylistCondition(field: .year, comparator: .equals, value: .integer(1972))
    #expect(cond.evaluate(track: rockTrack))
    #expect(!cond.evaluate(track: jazzTrack))
  }

  @Test("year greaterThan")
  func intGreaterThan() {
    let cond = PlaylistCondition(field: .year, comparator: .greaterThan, value: .integer(1960))
    #expect(cond.evaluate(track: rockTrack))
    #expect(!cond.evaluate(track: jazzTrack))
  }

  @Test("year inRange")
  func intInRange() {
    let cond = PlaylistCondition(field: .year, comparator: .inRange, value: .range(min: 1950, max: 1970))
    #expect(!cond.evaluate(track: rockTrack))
    #expect(cond.evaluate(track: jazzTrack))
  }

  // MARK: - Optional Int (year == nil)

  @Test("nil year: notEquals returns true, others return false")
  func optionalIntNil() {
    let eqCond = PlaylistCondition(field: .year, comparator: .equals, value: .integer(2024))
    let neCond = PlaylistCondition(field: .year, comparator: .notEquals, value: .integer(2024))
    let gtCond = PlaylistCondition(field: .year, comparator: .greaterThan, value: .integer(2000))

    #expect(!eqCond.evaluate(track: noYearTrack))
    #expect(neCond.evaluate(track: noYearTrack))
    #expect(!gtCond.evaluate(track: noYearTrack))
  }

  // MARK: - Duration (Double)

  @Test("duration greaterOrEqual")
  func doubleGreaterOrEqual() {
    let cond = PlaylistCondition(field: .duration, comparator: .greaterOrEqual, value: .double(180))
    #expect(cond.evaluate(track: rockTrack))
    let cond2 = PlaylistCondition(field: .duration, comparator: .greaterOrEqual, value: .double(181))
    #expect(!cond2.evaluate(track: rockTrack))
  }

  @Test("duration with integer value coercion")
  func durationIntegerCoercion() {
    let cond = PlaylistCondition(field: .duration, comparator: .lessThan, value: .integer(200))
    #expect(cond.evaluate(track: rockTrack))
  }

  // MARK: - Composite predicates

  @Test("allOf: AND logic")
  func allOf() {
    let predicate = PlaylistPredicate.allOf([
      .single(PlaylistCondition(field: .genre, comparator: .equals, value: .string("Rock"))),
      .single(PlaylistCondition(field: .year, comparator: .greaterThan, value: .integer(1960))),
    ])
    #expect(predicate.evaluate(track: rockTrack))
    #expect(!predicate.evaluate(track: jazzTrack))
  }

  @Test("anyOf: OR logic")
  func anyOf() {
    let predicate = PlaylistPredicate.anyOf([
      .single(PlaylistCondition(field: .genre, comparator: .equals, value: .string("Rock"))),
      .single(PlaylistCondition(field: .genre, comparator: .equals, value: .string("Jazz"))),
    ])
    #expect(predicate.evaluate(track: rockTrack))
    #expect(predicate.evaluate(track: jazzTrack))
    #expect(!predicate.evaluate(track: noYearTrack))
  }

  @Test("filter: returns matching tracks only")
  func filterTracks() {
    let predicate = PlaylistPredicate.single(
      PlaylistCondition(field: .genre, comparator: .equals, value: .string("Jazz"))
    )
    let result = predicate.filter(tracks: [rockTrack, jazzTrack, noYearTrack])
    #expect(result.count == 1)
    #expect(result.first?.title == "Take Five")
  }

  // MARK: - Codable round-trip

  @Test("PlaylistPredicate encodes and decodes correctly")
  func codableRoundTrip() throws {
    let predicate = PlaylistPredicate.allOf([
      .single(PlaylistCondition(field: .artist, comparator: .contains, value: .string("Purple"))),
      .anyOf([
        .single(PlaylistCondition(field: .year, comparator: .greaterThan, value: .integer(1970))),
        .single(PlaylistCondition(field: .duration, comparator: .inRange, value: .range(min: 60, max: 300))),
      ]),
    ])
    let encoder = JSONEncoder()
    let data = try encoder.encode(predicate)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(PlaylistPredicate.self, from: data)
    #expect(decoded == predicate)
  }

  // MARK: - Comparators for value kind

  @Test("Comparator.comparators(for:) returns correct sets")
  func comparatorsForKind() {
    let stringComps = Comparator.comparators(for: .string)
    #expect(stringComps.count == 6)
    #expect(stringComps.contains(.contains))
    #expect(!stringComps.contains(.greaterThan))

    let intComps = Comparator.comparators(for: .integer)
    #expect(intComps.count == 7)
    #expect(intComps.contains(.inRange))
    #expect(!intComps.contains(.contains))
  }

  // MARK: Private

  // MARK: - Test data

  private let rockTrack = makeTrack(
    title: "Highway Star", artist: "Deep Purple",
    albumTitle: "Machine Head", genre: "Rock", year: 1972
  )
  private let jazzTrack = makeTrack(
    title: "Take Five", artist: "Dave Brubeck",
    albumTitle: "Time Out", genre: "Jazz", year: 1959
  )
  private let noYearTrack = makeTrack(
    title: "Unknown Song", artist: "Unknown", albumTitle: "Mystery", genre: "Pop", year: nil
  )
}
