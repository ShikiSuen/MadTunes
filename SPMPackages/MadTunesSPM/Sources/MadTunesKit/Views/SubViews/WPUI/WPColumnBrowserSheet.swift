// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPColumnBrowserSheet

/// Phase 78: Column Browser for WPUI — vertical cascading filter sheet.
/// Adapts the desktop 4-column ColumnBrowserView into a mobile-friendly
/// DisclosureGroup layout per Plan Alpha / Plan Bravo specifications.
struct WPColumnBrowserSheet: View {
  // MARK: Internal

  var body: some View {
    @Bindable var bvm = vm
    NavigationStack {
      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 0) {
          // Phase 78: Genre → Album Artist → Song Artist → Album
          // Cascade filtering: selecting in one column narrows available items in others.
          WPFilterSection(
            title: String(localized: "i18n:ColumnBrowser.Genres", bundle: #bundle),
            allLabel: String(localized: "i18n:ColumnBrowser.AllGenres", bundle: #bundle),
            items: vm.columnBrowserGenres,
            selection: $bvm.columnBrowserSelectedGenres,
            accentColor: phoneVM.wpAccentColor.color
          ) {
            vm.columnBrowserSelectedAlbumArtists.formIntersection(Set(vm.columnBrowserAlbumArtists))
            vm.columnBrowserSelectedSongArtists.formIntersection(Set(vm.columnBrowserSongArtists))
            vm.columnBrowserSelectedAlbumTitles.formIntersection(Set(vm.columnBrowserAlbumTitles))
          }

          WPFilterSection(
            title: String(localized: "i18n:ColumnBrowser.AlbumArtists", bundle: #bundle),
            allLabel: String(localized: "i18n:ColumnBrowser.AllAlbumArtists", bundle: #bundle),
            items: vm.columnBrowserAlbumArtists,
            selection: $bvm.columnBrowserSelectedAlbumArtists,
            accentColor: phoneVM.wpAccentColor.color
          ) {
            vm.columnBrowserSelectedSongArtists.formIntersection(Set(vm.columnBrowserSongArtists))
            vm.columnBrowserSelectedAlbumTitles.formIntersection(Set(vm.columnBrowserAlbumTitles))
          }

          WPFilterSection(
            title: String(localized: "i18n:ColumnBrowser.SongArtists", bundle: #bundle),
            allLabel: String(localized: "i18n:ColumnBrowser.AllSongArtists", bundle: #bundle),
            items: vm.columnBrowserSongArtists,
            selection: $bvm.columnBrowserSelectedSongArtists,
            accentColor: phoneVM.wpAccentColor.color
          ) {
            vm.columnBrowserSelectedAlbumArtists.formIntersection(Set(vm.columnBrowserAlbumArtists))
            vm.columnBrowserSelectedAlbumTitles.formIntersection(Set(vm.columnBrowserAlbumTitles))
          }

          WPFilterSection(
            title: String(localized: "i18n:ColumnBrowser.Albums", bundle: #bundle),
            allLabel: String(localized: "i18n:ColumnBrowser.AllAlbums", bundle: #bundle),
            items: vm.columnBrowserAlbumTitles,
            selection: $bvm.columnBrowserSelectedAlbumTitles,
            accentColor: phoneVM.wpAccentColor.color
          ) {}
        }
        .padding(.vertical, 8)
      }
      .background(Color.black)
      .navigationTitle(String(localized: "i18n:ColumnBrowser.Title", bundle: #bundle))
      #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "i18n:Common.Done", bundle: #bundle)) {
              phoneVM.isColumnBrowserPresented = false
            }
          }
          if vm.isColumnBrowserFiltering {
            ToolbarItem(placement: .cancellationAction) {
              Button(role: .destructive) {
                vm.resetColumnBrowserFilters()
              } label: {
                Text(String(localized: "i18n:ColumnBrowser.ClearAll", bundle: #bundle))
                  .foregroundStyle(.red)
              }
            }
          }
        }
      #if !os(macOS)
        .toolbarColorScheme(.dark, for: .navigationBar)
      #endif
    }
    .preferredColorScheme(.dark)
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM
}

// MARK: - WPFilterSection

/// A collapsible filter section with checkbox multi-select, styled for WP Metro dark theme.
private struct WPFilterSection: View {
  let title: String
  let allLabel: String
  let items: [String]
  @Binding var selection: Set<String>
  let accentColor: Color
  let onSelectionChange: () -> Void

  @State private var isExpanded = false

  var body: some View {
    VStack(spacing: 0) {
      // Section header (tap to expand/collapse).
      Button {
        withAnimation(.interactiveSpring) {
          isExpanded.toggle()
        }
      } label: {
        HStack {
          Text(verbatim: title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
          Spacer()
          if !selection.isEmpty {
            Text(verbatim: "\(selection.count)")
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(accentColor)
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
              .background(accentColor.opacity(0.2))
              .clipShape(Capsule())
          }
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      if isExpanded {
        // "All" row.
        Button {
          selection = []
          onSelectionChange()
        } label: {
          HStack(spacing: 12) {
            Image(systemName: selection.isEmpty ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(selection.isEmpty ? accentColor : .white.opacity(0.3))
              .font(.system(size: 20))
            Text(verbatim: allLabel)
              .font(.system(size: 15))
              .foregroundStyle(.white)
            Spacer()
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 8)
          .contentShape(.rect)
        }
        .buttonStyle(.plain)

        // Individual filter items.
        ForEach(items, id: \.self) { item in
          Button {
            if selection.contains(item) {
              selection.remove(item)
            } else {
              selection.insert(item)
            }
            onSelectionChange()
          } label: {
            HStack(spacing: 12) {
              Image(systemName: selection.contains(item) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selection.contains(item) ? accentColor : .white.opacity(0.3))
                .font(.system(size: 20))
              Text(verbatim: item)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .lineLimit(1)
              Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .contentShape(.rect)
          }
          .buttonStyle(.plain)
        }
      }

      Divider()
        .background(Color.white.opacity(0.15))
    }
  }
}
