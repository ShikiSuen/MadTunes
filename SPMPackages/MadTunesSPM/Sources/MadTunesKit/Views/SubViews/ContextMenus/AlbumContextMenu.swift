// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - AlbumContextMenu

/// 專輯右鍵選單，用於 AlbumGridItemView。
struct AlbumContextMenu: View {
  // MARK: Lifecycle

  init(
    albums: [Album],
    library: MusicLibrary,
    audioPlayer: AudioPlayer,
    currentPlaylistID: UUID? = nil,
    searchText: String = "",
    searchFilterMode: SearchFilterMode = .either,
    onShowTrackInfo: @escaping () -> Void,
    onShowDeleteConfirmation: @escaping () -> Void,
    onNewPlaylistWithTracks: @escaping (Set<UUID>) -> Void = { _ in }
  ) {
    self.albums = albums
    self.library = library
    self.audioPlayer = audioPlayer
    self.currentPlaylistID = currentPlaylistID
    self.searchText = searchText
    self.searchFilterMode = searchFilterMode
    self.onShowTrackInfo = onShowTrackInfo
    self.onShowDeleteConfirmation = onShowDeleteConfirmation
    self.onNewPlaylistWithTracks = onNewPlaylistWithTracks
  }

  // MARK: Internal

  var body: some View {
    // 加入到播放清單（子選單）
    Menu {
      // 常駐項：新增播放清單
      Button {
        onNewPlaylistWithTracks(trackIDs)
      } label: {
        Label(String(localized: "i18n:Sidebar.NewPlaylist", bundle: #bundle), systemImage: "plus")
      }
      Divider()
      ForEach(Array(library.playlists.dropFirst(2))) { playlist in
        Button {
          library.addTracks(trackIDs, toPlaylist: playlist.id)
        } label: {
          Text(playlist.name)
        }
      }
    } label: {
      Label(String(localized: "i18n:ContextMenu.AddToPlaylist", bundle: #bundle), systemImage: "text.badge.plus")
    }

    Divider()

    let tracks = sortedTracks
    if !tracks.isEmpty {
      // 播放選項
      Button {
        audioPlayer.setQueue(tracks, startingAt: 0)
      } label: {
        Label(String(localized: "i18n:ContextMenu.PlayAlbum", bundle: #bundle), systemImage: "play.fill")
      }

      Button {
        audioPlayer.setQueue(tracks.shuffled(), startingAt: 0)
      } label: {
        Label(String(localized: "i18n:ContextMenu.ShuffleAlbum", bundle: #bundle), systemImage: "shuffle")
      }

      Button {
        audioPlayer.insertNext(tracks)
      } label: {
        Label(
          String(localized: "i18n:ContextMenu.PlayNext", bundle: #bundle),
          systemImage: "text.line.first.and.arrowtriangle.forward"
        )
      }

      Divider()
    }

    // 取得資訊
    Button {
      onShowTrackInfo()
    } label: {
      Label(String(localized: "i18n:ContextMenu.GetInfo", bundle: #bundle), systemImage: "info.circle")
    }

    // 加入喜好項目
    Button {
      library.toggleFavorite(trackIDs: trackIDs)
    } label: {
      Label(
        allTracksFavorited
          ? String(localized: "i18n:ContextMenu.RemoveFromFavorites", bundle: #bundle)
          : String(localized: "i18n:ContextMenu.AddToFavorites", bundle: #bundle),
        systemImage: allTracksFavorited ? "heart.fill" : "heart"
      )
    }

    Divider()

    // 顯示於檔案總管
    #if os(macOS)
    Button {
      showInFinder()
    } label: {
      Label(String(localized: "i18n:ContextMenu.ShowInFinder", bundle: #bundle), systemImage: "folder")
    }
    #endif

    Divider()

    // 從資料庫刪除登記
    Button(role: .destructive) {
      onShowDeleteConfirmation()
    } label: {
      Label(String(localized: "i18n:ContextMenu.RemoveFromLibrary", bundle: #bundle), systemImage: "trash")
    }

    // 移出當前播放清單（僅靜態播放清單）
    if let playlistID = currentStaticPlaylistID {
      Divider()
      Button(role: .destructive) {
        library.removeTracksFromPlaylist(trackIDs, playlistID: playlistID)
      } label: {
        Label(String(localized: "i18n:ContextMenu.RemoveFromPlaylist", bundle: #bundle), systemImage: "minus.circle")
      }
    }
  }

  // MARK: Private

  private let albums: [Album]
  private let library: MusicLibrary
  private let audioPlayer: AudioPlayer
  private let currentPlaylistID: UUID?
  private let searchText: String
  private let searchFilterMode: SearchFilterMode
  private let onShowTrackInfo: () -> Void
  private let onShowDeleteConfirmation: () -> Void
  private let onNewPlaylistWithTracks: (Set<UUID>) -> Void

  private var allTracks: [Track] {
    albums.flatMap(\.tracks)
  }

  private var sortedTracks: [Track] {
    let tracks = allTracks.sorted {
      ($0.albumTitle, $0.discNumber, $0.trackNumber, $0.title)
        < ($1.albumTitle, $1.discNumber, $1.trackNumber, $1.title)
    }

    let query = searchText.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else {
      return tracks
    }

    // 專輯名稱模式：返回所有曲目（因為專輯本身已經被過濾顯示）
    if searchFilterMode == .albumTitle {
      return tracks
    }

    return tracks.filter { track in
      switch searchFilterMode {
      case .trackTitle:
        return track.title.localizedCaseInsensitiveContains(query)
      case .albumTitle:
        return true // 已由上方處理
      case .artist:
        return track.artist.localizedCaseInsensitiveContains(query)
          || track.albumArtist.localizedCaseInsensitiveContains(query)
      case .either:
        return track.title.localizedCaseInsensitiveContains(query)
          || track.artist.localizedCaseInsensitiveContains(query)
          || track.albumArtist.localizedCaseInsensitiveContains(query)
      }
    }
  }

  private var trackIDs: Set<UUID> {
    Set(allTracks.map(\.id))
  }

  private var allTracksFavorited: Bool {
    guard !allTracks.isEmpty else { return false }
    let favorites = library.favoritesPlaylist.trackIDs
    return allTracks.allSatisfy { favorites.contains($0.id) }
  }

  /// 當前正在檢視的靜態播放清單 ID（若有）。
  private var currentStaticPlaylistID: UUID? {
    guard let id = currentPlaylistID,
          let playlist = library.playlists.first(where: { $0.id == id }),
          playlist.kind == .staticList else { return nil }
    return id
  }

  #if os(macOS)
  private func showInFinder() {
    guard let url = albums.first?.tracks.first?.fileURL else { return }
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
  #endif
}
