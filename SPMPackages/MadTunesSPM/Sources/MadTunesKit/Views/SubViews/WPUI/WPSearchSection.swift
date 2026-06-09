// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPSearchSection

/// Phase 75: Search section of the Panorama Hub.
/// Provides a search bar and displays results as album tiles + track list.
struct WPSearchSection: View {
  // MARK: Internal

  var body: some View {
    @Bindable var pvm = phoneVM
    VStack(spacing: 0) {
      // Search bar.
      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.white.opacity(0.5))
        TextField(
          String(localized: "i18n:Search.Prompt", bundle: #bundle),
          text: $pvm.phoneSearchText
        )
        .textFieldStyle(.plain)
        .foregroundStyle(.white)
        .autocorrectionDisabled()
        #if !os(macOS)
          .textInputAutocapitalization(.never)
        #endif

        if !phoneVM.phoneSearchText.isEmpty {
          Button {
            phoneVM.phoneSearchText = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.white.opacity(0.5))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(Color.white.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .padding(.horizontal, 16)
      .padding(.top, 8)

      // Results.
      let results = phoneVM.phoneSearchResults
      if phoneVM.phoneSearchText.isEmpty {
        Spacer()
        Text(String(localized: "i18n:WP.Search.Hint", bundle: #bundle))
          .font(.system(size: 15))
          .foregroundStyle(.white.opacity(0.4))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
        Spacer()
      } else if results.albums.isEmpty, results.tracks.isEmpty {
        Spacer()
        Text(String(localized: "i18n:WP.Search.NoResults", bundle: #bundle))
          .font(.system(size: 15))
          .foregroundStyle(.white.opacity(0.4))
        Spacer()
      } else {
        ScrollView(.vertical, showsIndicators: false) {
          LazyVStack(alignment: .leading, spacing: 12) {
            // Album results as small tiles in horizontal scroll.
            if !results.albums.isEmpty {
              Text(String(localized: "i18n:WP.Pivot.Albums", bundle: #bundle))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.top, 12)

              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                  ForEach(results.albums) { album in
                    Button {
                      phoneVM.navigationPath.append(
                        WPNavigationDestination.albumDetail(album)
                      )
                    } label: {
                      VStack(alignment: .leading, spacing: 4) {
                        LazyAlbumArtworkView(album: album)
                          .frame(width: 100, height: 100)
                          .clipShape(Rectangle())
                        Text(verbatim: album.title)
                          .font(.system(size: 12))
                          .foregroundStyle(.white)
                          .lineLimit(1)
                        Text(verbatim: album.artist)
                          .font(.system(size: 11))
                          .foregroundStyle(.white.opacity(0.5))
                          .lineLimit(1)
                      }
                      .frame(width: 100)
                    }
                    .buttonStyle(.plain)
                  }
                }
                .padding(.horizontal, 20)
              }
              .scrollEdgeSoftened()
            }

            // Track results.
            if !results.tracks.isEmpty {
              Text(String(localized: "i18n:WP.Pivot.Tracks", bundle: #bundle))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.top, 4)

              WPTrackListView(tracks: Array(results.tracks.prefix(50)))
            }
          }
        }
        .scrollEdgeSoftened()
      }
    }
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM
}
