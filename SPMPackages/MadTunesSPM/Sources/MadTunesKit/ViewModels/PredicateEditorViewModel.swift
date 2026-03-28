// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import Observation

// MARK: - PredicateEditorViewModel

/// Shared editor state for both desktop and WPUI predicate editors.
@Observable
@MainActor
final class PredicateEditorViewModel {
  // MARK: Lifecycle

  init(playlist: Playlist, library: MusicLibraryProviding) {
    self.playlistID = playlist.id
    self.playlistName = playlist.name
    self.libraryProvider = library

    // Decode existing predicate or start with empty allOf.
    if !playlist.predicateData.isEmpty,
       let decoded = try? JSONDecoder().decode(PlaylistPredicate.self, from: playlist.predicateData) {
      switch decoded {
      case let .allOf(children):
        self.matchMode = .all
        self.rootNodes = children.map(PredicateNode.from)
      case let .anyOf(children):
        self.matchMode = .any
        self.rootNodes = children.map(PredicateNode.from)
      case let .single(single):
        self.matchMode = .all
        self.rootNodes = [.leaf(single)]
      }
    } else {
      self.matchMode = .all
      self.rootNodes = []
    }
  }

  // MARK: Internal

  // MARK: - PredicateNode

  /// Identifiable tree node for the predicate editor UI.
  /// Uses flat struct layout for SwiftUI binding compatibility.
  struct PredicateNode: Identifiable {
    // MARK: Internal

    let id: UUID
    var isGroup: Bool
    /// Leaf predicate (used only when `isGroup == false`).
    var leafPredicate: PlaylistCondition
    /// Group match mode (used only when `isGroup == true`).
    var groupMode: MatchMode
    /// Group children (used only when `isGroup == true`).
    var children: [PredicateNode]

    static func leaf(_ predicate: PlaylistCondition) -> Self {
      PredicateNode(
        id: UUID(), isGroup: false,
        leafPredicate: predicate,
        groupMode: .all, children: []
      )
    }

    static func group(mode: MatchMode, children: [PredicateNode] = []) -> Self {
      PredicateNode(
        id: UUID(), isGroup: true,
        leafPredicate: Self.defaultLeafPredicate,
        groupMode: mode, children: children
      )
    }

    static func from(_ predicate: PlaylistPredicate) -> PredicateNode {
      switch predicate {
      case let .single(single): return .leaf(single)
      case let .allOf(children): return .group(mode: .all, children: children.map(from))
      case let .anyOf(children): return .group(mode: .any, children: children.map(from))
      }
    }

    func toPredicate() -> PlaylistPredicate {
      if isGroup {
        let childPredicates = children.map { $0.toPredicate() }
        return groupMode == .all ? .allOf(childPredicates) : .anyOf(childPredicates)
      }
      return .single(leafPredicate)
    }

    // MARK: Private

    private static let defaultLeafPredicate = PlaylistCondition(
      field: .title,
      comparator: .contains,
      value: .string("")
    )
  }

  // MARK: - MatchMode

  enum MatchMode: String, CaseIterable {
    case all
    case any
  }

  var matchMode: MatchMode
  var rootNodes: [PredicateNode]

  let playlistName: String

  var playlist: Playlist? {
    libraryProvider.playlists.first(where: { $0.id == playlistID })
  }

  var dataSourceLibrary: any MusicLibraryProviding { libraryProvider }

  var hasAnyPredicates: Bool { !rootNodes.isEmpty }

  func matchingTrackCount() -> Int? {
    guard let predicate = buildPredicate() else { return nil }
    return predicate.filter(tracks: matchingTrackSource()).count
  }

  func buildPredicate() -> PlaylistPredicate? {
    guard !rootNodes.isEmpty else { return nil }
    let children = rootNodes.map { $0.toPredicate() }
    switch matchMode {
    case .all: return .allOf(children)
    case .any: return .anyOf(children)
    }
  }

  func applyChanges() {
    let data: Data
    if let predicate = buildPredicate() {
      data = (try? JSONEncoder().encode(predicate)) ?? Data()
    } else {
      data = Data()
    }
    libraryProvider.updatePredicateData(playlistID: playlistID, data: data)
  }

  // MARK: Private

  private let playlistID: UUID
  private let libraryProvider: any MusicLibraryProviding

  private func matchingTrackSource() -> [Track] {
    guard let playlist, playlist.kind == .dynamicList else {
      return libraryProvider.tracks
    }

    let sourceIDs = playlist.sourceFolderPlaylistIDSet
    guard !sourceIDs.isEmpty else { return libraryProvider.tracks }

    var sourceTracks: [Track] = []
    for sourceID in sourceIDs {
      guard let sourcePlaylist = libraryProvider.playlists.first(where: { $0.id == sourceID && $0.kind == .folderList })
      else { continue }
      sourceTracks.append(contentsOf: libraryProvider.tracksForFolderPlaylist(sourcePlaylist))
    }
    return sourceTracks
  }
}
