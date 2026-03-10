// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - TrackContextMenu

/// 樂曲右鍵選單，用於 ExpandedAlbumView 內的 TrackRow。
struct TrackContextMenu: View {
  // MARK: Lifecycle

  init(
    tracks: [Track],
    library: MusicLibrary,
    audioPlayer: AudioPlayer,
    currentPlaylistID: UUID? = nil,
    onShowTrackInfo: @escaping () -> Void,
    onShowDeleteConfirmation: @escaping () -> Void
  ) {
    self.tracks = tracks
    self.library = library
    self.audioPlayer = audioPlayer
    self.currentPlaylistID = currentPlaylistID
    self.onShowTrackInfo = onShowTrackInfo
    self.onShowDeleteConfirmation = onShowDeleteConfirmation
  }

  // MARK: Internal

  let tracks: [Track]
  let library: MusicLibrary
  let audioPlayer: AudioPlayer
  let currentPlaylistID: UUID?
  let onShowTrackInfo: () -> Void
  let onShowDeleteConfirmation: () -> Void

  var body: some View {
    // 加入到播放清單（子選單）
    Menu {
      ForEach(Array(library.playlists.dropFirst(2))) { playlist in
        Button {
          library.addTracks(trackIDs, toPlaylist: playlist.id)
        } label: {
          Text(playlist.name)
        }
      }
    } label: {
      Label("Add to Playlist", systemImage: "text.badge.plus")
    }

    Divider()

    // 插播
    Button {
      audioPlayer.insertAndPlay(tracks)
    } label: {
      Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
    }

    Divider()

    // 取得資訊
    Button {
      onShowTrackInfo()
    } label: {
      Label("Get Info", systemImage: "info.circle")
    }

    // 加入喜好項目
    Button {
      library.toggleFavorite(trackIDs: trackIDs)
    } label: {
      Label(
        allTracksFavorited ? "Remove from Favorites" : "Add to Favorites",
        systemImage: allTracksFavorited ? "heart.fill" : "heart"
      )
    }

    Divider()

    // 拷貝中繼資料
    Button {
      copyMetadataToClipboard()
    } label: {
      Label("Copy Metadata", systemImage: "doc.on.doc")
    }

    Divider()

    // 顯示於檔案總管
    #if os(macOS)
    Button {
      showInFinder()
    } label: {
      Label("Show in Finder", systemImage: "folder")
    }

    Divider()
    #endif

    // 從資料庫刪除登記
    Button(role: .destructive) {
      onShowDeleteConfirmation()
    } label: {
      Label("Remove from Library", systemImage: "trash")
    }

    // 移出當前播放清單（僅靜態播放清單）
    if let playlistID = currentStaticPlaylistID {
      Divider()
      Button(role: .destructive) {
        library.removeTracksFromPlaylist(trackIDs, playlistID: playlistID)
      } label: {
        Label("Remove from Playlist", systemImage: "minus.circle")
      }
    }
  }

  // MARK: Private

  private var trackIDs: Set<UUID> {
    Set(tracks.map(\.id))
  }

  private var allTracksFavorited: Bool {
    guard !tracks.isEmpty else { return false }
    let favorites = library.favoritesPlaylist.trackIDs
    return tracks.allSatisfy { favorites.contains($0.id) }
  }

  /// 當前正在檢視的靜態播放清單 ID（若有）。
  private var currentStaticPlaylistID: UUID? {
    guard let id = currentPlaylistID,
          let playlist = library.playlists.first(where: { $0.id == id }),
          playlist.kind == .staticList else { return nil }
    return id
  }

  private func copyMetadataToClipboard() {
    let tsv = tracksToTSV(tracks)
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(tsv, forType: .string)
    #else
    UIPasteboard.general.string = tsv
    #endif
  }

  #if os(macOS)
  private func showInFinder() {
    let urls = tracks.map(\.fileURL)
    NSWorkspace.shared.activateFileViewerSelecting(urls)
  }
  #endif
}
