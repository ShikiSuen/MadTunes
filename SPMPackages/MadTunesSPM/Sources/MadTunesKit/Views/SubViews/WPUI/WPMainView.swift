// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPMainView

/// Phase 75: Panorama Hub — the top-level container for the WP Metro-style iPhone UI.
/// Uses a horizontal paging TabView to create the Panorama experience.
struct WPMainView: View {
  // MARK: Internal

  var body: some View {
    NavigationStack(path: $phoneVM.navigationPath) {
      ZStack(alignment: .bottom) {
        // Phase 77: Panorama hub background — MeshGradient replaces plain black,
        // visible through all transparent sections including NowPlaying.
        Gradient.colorMeshGradient
          .overlay {
            LinearGradient(
              colors: [
                .black,
                .black.opacity(0.2),
                .black.opacity(0),
              ],
              startPoint: .top,
              endPoint: .bottom
            )
            .blendMode(.darken)
          }
          .ignoresSafeArea()

        VStack(spacing: 0) {
          // Phase 75: Global title with parallax hint.
          HStack {
            Text(verbatim: "MadTunes".lowercased())
              .font(.system(size: 44, weight: .light))
              .fontWidth(.standard)
              .foregroundStyle(.white.opacity(0.4))
              .offset(x: parallaxOffset)
            Spacer()
          }
          .padding(.horizontal, 20)
          .padding(.top, 8)

          // Section titles row.
          WPSectionTitlesBar(
            currentSection: $phoneVM.currentSection,
            accentColor: phoneVM.wpAccentColor.color
          )

          // Panorama paged content.
          TabView(selection: $phoneVM.currentSection) {
            WPNowPlayingSection()
              .tag(WPPhoneViewModel.PanoramaSection.nowPlaying)

            WPLibrarySection()
              .tag(WPPhoneViewModel.PanoramaSection.library)

            WPPlaylistsSection()
              .tag(WPPhoneViewModel.PanoramaSection.playlists)

            WPSearchSection()
              .tag(WPPhoneViewModel.PanoramaSection.search)
          }
          #if os(iOS)
          .tabViewStyle(.page(indexDisplayMode: .never))
          #endif

          // Mini player (visible when not on Now Playing).
          if phoneVM.currentSection != .nowPlaying,
             vm.player.currentTrack != nil {
            WPMiniPlayerBar(accentColor: phoneVM.wpAccentColor.color)
              .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        }
      }
      .overlay {
        Group {
          // Empty library overlay.
          if !vm.library.isImporting,
             vm.library.hasLoadedPersistence,
             vm.library.tracks.isEmpty {
            WPEmptyLibraryOverlay()
          } else if vm.library.isImporting {
            WPImportingOverlay()
          } else if !vm.library.hasLoadedPersistence {
            WPLoadingOverlay()
          }
        }
        .background(
          LinearGradient(
            colors: [
              .init(white: 0),
              .init(white: 0, opacity: 0),
              .init(white: 0, opacity: 0),
              .init(white: 0, opacity: 0),
              .init(white: 0),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .background(.thinMaterial)
          .ignoresSafeArea()
        )
      }
      .animation(
        .interactiveSpring.nerf(vm.gridVM.legacyHardwareMode),
        value: phoneVM.currentSection
      )
      .preferredColorScheme(.dark)
      .environment(vm)
      .environment(phoneVM)
      .navigationDestination(for: WPNavigationDestination.self) { destination in
        switch destination {
        case let .albumDetail(album):
          WPAlbumDetailView(album: album)
            .environment(vm)
            .environment(phoneVM)
        case let .artistDetail(artist):
          WPArtistDetailView(artistName: artist)
            .environment(vm)
            .environment(phoneVM)
        case let .playlistDetail(playlist):
          WPPlaylistDetailView(playlist: playlist)
            .environment(vm)
            .environment(phoneVM)
        }
      }
      .fileImporter(
        isPresented: $vm.isFileImporterPresented,
        allowedContentTypes: SupportedFormats.fileImportTypes,
        allowsMultipleSelection: true
      ) { result in
        if case let .success(urls) = result {
          vm.importURLs(urls)
        }
      }
      .fileImporter(
        isPresented: $vm.isFolderImporterPresented,
        allowedContentTypes: SupportedFormats.folderImportTypes,
        allowsMultipleSelection: true
      ) { result in
        if case let .success(urls) = result {
          vm.importURLs(urls)
        }
      }
      .fileImporter(
        isPresented: $phoneVM.isFolderImporterPresented,
        allowedContentTypes: [.folder],
        allowsMultipleSelection: false
      ) { result in
        switch result {
        case let .success(urls):
          guard let folderURL = urls.first else { return }
          // addFolderPlaylist manages security-scoped access internally.
          let playlistName = folderURL.deletingPathExtension().lastPathComponent
          Task {
            await vm.library.addFolderPlaylist(name: playlistName, folderURL: folderURL)
          }
        case .failure:
          break
        }
      }
    }
    // Phase 77: Alerts and sheets moved outside NavigationStack so they present
    // immediately regardless of navigation depth (fixes delayed alert on pop-back).
    .sheet(isPresented: $phoneVM.isTrackInfoPresented) {
      if phoneVM.tracksForTrackInfo.count == 1,
         let track = phoneVM.tracksForTrackInfo.first {
        TrackInfoView(track: track, detailedMetadata: nil)
      } else {
        MultiTrackInfoView(
          tracks: phoneVM.tracksForTrackInfo,
          detailedMetadataList: []
        )
      }
    }
    .alert(
      String(localized: "i18n:Alert.RemoveFromLibraryTitle", bundle: #bundle),
      isPresented: $phoneVM.showDeleteConfirmation
    ) {
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
      Button(String(localized: "i18n:Common.Remove", bundle: #bundle), role: .destructive) {
        let trackIDs = Set(phoneVM.albumsToDelete.flatMap { $0.tracks.map(\.id) })
        Task {
          await vm.removeTracksFromLibrary(trackIDs)
        }
        phoneVM.albumsToDelete = []
      }
    } message: {
      Text("i18n:Alert.RemoveAlbumsMessage:\(phoneVM.albumsToDelete.count)", bundle: #bundle)
    }
    .alert(
      String(localized: "i18n:Alert.RemoveFromLibraryTitle", bundle: #bundle),
      isPresented: $phoneVM.showTrackDeleteConfirmation
    ) {
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
      Button(String(localized: "i18n:Common.Remove", bundle: #bundle), role: .destructive) {
        let trackIDs = Set(phoneVM.tracksToDelete.map(\.id))
        Task {
          await vm.removeTracksFromLibrary(trackIDs)
        }
        phoneVM.tracksToDelete = []
      }
    } message: {
      Text("i18n:Alert.RemoveTracksMessage:\(phoneVM.tracksToDelete.count)", bundle: #bundle)
    }
    .alert(
      String(localized: "i18n:Sidebar.Alert.NewPlaylistTitle", bundle: #bundle),
      isPresented: $phoneVM.showNewPlaylistAlert
    ) {
      TextField(
        String(localized: "i18n:Sidebar.Alert.PlaylistNamePlaceholder", bundle: #bundle),
        text: $phoneVM.newPlaylistName
      )
      Button(String(localized: "i18n:Common.Create", bundle: #bundle)) {
        phoneVM.commitNewPlaylist()
      }
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
    }
    // Phase 78: Column Browser sheet.
    .sheet(isPresented: $phoneVM.isColumnBrowserPresented) {
      WPColumnBrowserSheet()
        .environment(vm)
        .environment(phoneVM)
    }
    // Phase 78: Playing Queue sheet.
    .sheet(isPresented: $phoneVM.isQueuePresented) {
      WPQueueSheet()
        .environment(vm)
        .environment(phoneVM)
    }
    // Phase 78: Accent Color picker sheet.
    .sheet(isPresented: $phoneVM.isAccentColorPickerPresented) {
      WPAccentColorPicker()
        .environment(phoneVM)
    }
    // Phase 78: Create playlist alert (from Playlists section + button).
    .alert(
      String(localized: "i18n:Sidebar.Alert.NewPlaylistTitle", bundle: #bundle),
      isPresented: $phoneVM.isCreatePlaylistAlertPresented
    ) {
      TextField(
        String(localized: "i18n:Sidebar.Alert.PlaylistNamePlaceholder", bundle: #bundle),
        text: $phoneVM.createPlaylistName
      )
      Button(String(localized: "i18n:Common.Create", bundle: #bundle)) {
        phoneVM.commitCreatePlaylist()
      }
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
    }
    // Phase 78: Rename playlist alert.
    .alert(
      String(localized: "i18n:Sidebar.Alert.RenamePlaylistTitle", bundle: #bundle),
      isPresented: $phoneVM.isRenamePlaylistAlertPresented
    ) {
      TextField(
        String(localized: "i18n:Sidebar.Alert.NewNamePlaceholder", bundle: #bundle),
        text: $phoneVM.renamePlaylistName
      )
      Button(String(localized: "i18n:Common.Done", bundle: #bundle)) {
        phoneVM.commitRenamePlaylist()
      }
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
    }
    .tint(phoneVM.wpAccentColor.color)
    .environment(\.colorScheme, .dark)
    .task {
      await vm.library.loadPersistedData()
      vm.selectedPlaylistID = vm.library.playlists.first?.id
    }
    .trackScreenVMParameters()
  }

  // MARK: Private

  @State private var vm = MadTunesViewModel.shared
  @State private var phoneVM: WPPhoneViewModel = {
    MadTunesViewModel.shared.phoneVM
  }()

  /// Parallax offset for the global title, tied to current section index.
  private var parallaxOffset: CGFloat {
    CGFloat(phoneVM.currentSection.rawValue) * -40
  }
}

// MARK: - WPNavigationDestination

/// Navigation destinations for WP drill-down views.
enum WPNavigationDestination: Hashable {
  case albumDetail(Album)
  case artistDetail(String)
  case playlistDetail(Playlist)
}

// MARK: - WPSectionTitlesBar

/// Horizontal section title bar mimicking the WP Panorama header.
struct WPSectionTitlesBar: View {
  @Binding var currentSection: WPPhoneViewModel.PanoramaSection

  @State private var vm = MadTunesViewModel.shared

  let accentColor: Color

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 20) {
          ForEach(WPPhoneViewModel.PanoramaSection.allCases) { section in
            Button {
              withAnimation(.interactiveSpring.nerf(vm.gridVM.legacyHardwareMode)) {
                currentSection = section
              }
            } label: {
              VStack(spacing: 4) {
                Text(section.localizedTitle.lowercased())
                  .font(.system(size: 22, weight: .regular))
                  .foregroundStyle(currentSection == section ? .white : .white.opacity(0.5))
                  .id(section)

                // Accent underline for selected section.
                Rectangle()
                  .fill(currentSection == section ? accentColor : .clear)
                  .frame(height: 2)
              }
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
      }
      .onChange(of: currentSection) { _, newSection in
        withAnimation {
          proxy.scrollTo(newSection, anchor: .center)
        }
      }
    }
  }
}

// MARK: - WPEmptyLibraryOverlay

/// Shown when the library has no tracks. Provides import buttons and a share tip.
struct WPEmptyLibraryOverlay: View {
  // MARK: Internal

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "music.note")
        .font(.system(size: 48))
        .foregroundStyle(.white.opacity(0.3))

      Text(String(localized: "i18n:EmptyState.NoMusic", bundle: #bundle))
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(.white)
      Text(String(localized: "i18n:EmptyState.ImportPrompt", bundle: #bundle))
        .font(.system(size: 15))
        .foregroundStyle(.white.opacity(0.6))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      VStack(spacing: 10) {
        Button {
          vm.isFileImporterPresented = true
        } label: {
          Label(
            String(localized: "i18n:Import.ImportFiles", bundle: #bundle),
            systemImage: "doc.badge.plus"
          )
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 10)
          .background(Color.white.opacity(0.15))
          .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)

        Button {
          vm.isFolderImporterPresented = true
        } label: {
          Label(
            String(localized: "i18n:Import.ImportFolder", bundle: #bundle),
            systemImage: "folder.badge.plus"
          )
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 10)
          .background(Color.white.opacity(0.15))
          .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
      }
      .padding(.top, 8)

      Text(String(localized: "i18n:EmptyState.ImportPromptShareTip", bundle: #bundle))
        .font(.system(size: 13))
        .foregroundStyle(.white.opacity(0.4))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
}

// MARK: - WPImportingOverlay

/// Shown during music import with progress indicator.
struct WPImportingOverlay: View {
  // MARK: Internal

  var body: some View {
    VStack(spacing: 12) {
      let progress = vm.library.importProgress
      WinUI3ProgressRing()
        .frame(width: 48, height: 48)
      Text(String(localized: "i18n:Import.ImportingMusic", bundle: #bundle))
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
      if progress.totalCount > 0 {
        Text(verbatim: "\(progress.finishedCount)/\(progress.totalCount)")
          .font(.system(size: 14, design: .monospaced))
          .foregroundStyle(.white.opacity(0.6))
      }
      if !progress.fileName.isEmpty {
        Text(progress.fileName)
          .font(.system(size: 12))
          .foregroundStyle(.white.opacity(0.4))
          .lineLimit(1)
          .truncationMode(.middle)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
}

// MARK: - WPLoadingOverlay

/// Shown while persistence data is being loaded.
struct WPLoadingOverlay: View {
  var body: some View {
    VStack(spacing: 12) {
      WinUI3ProgressRing()
        .frame(width: 48, height: 48)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - WPQueueSheet

/// Phase 78: Playing Queue sheet for WPUI.
/// Shows the current playback queue with tap-to-play and swipe-to-remove.
struct WPQueueSheet: View {
  // MARK: Internal

  var body: some View {
    NavigationStack {
      Group {
        if vm.player.queue.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "music.note.list")
              .font(.system(size: 40))
              .foregroundStyle(.white.opacity(0.3))
            Text(String(localized: "i18n:Queue.Empty", bundle: #bundle))
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(.white.opacity(0.6))
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          List {
            ForEach(Array(vm.player.queue.enumerated()), id: \.offset) { index, track in
              Button {
                Task {
                  await vm.player.setQueue(vm.player.queue, startingAt: index)
                }
              } label: {
                HStack(spacing: 12) {
                  if index == vm.player.currentIndex, vm.player.isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                      .font(.system(size: 12))
                      .foregroundStyle(phoneVM.wpAccentColor.color)
                      .frame(width: 20)
                  } else {
                    Text(verbatim: "\(index + 1)")
                      .font(.system(size: 13, design: .monospaced))
                      .foregroundStyle(.white.opacity(0.4))
                      .frame(width: 20, alignment: .trailing)
                  }
                  VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: track.title)
                      .font(.system(size: 15))
                      .foregroundStyle(index == vm.player.currentIndex ? phoneVM.wpAccentColor.color : .white)
                      .lineLimit(1)
                    Text(verbatim: track.artist)
                      .font(.system(size: 12))
                      .foregroundStyle(.white.opacity(0.5))
                      .lineLimit(1)
                  }
                  Spacer()
                }
              }
              .listRowBackground(Color.black)
            }
            .onDelete { indexSet in
              var newQueue = vm.player.queue
              for index in indexSet.sorted().reversed() {
                guard newQueue.indices.contains(index) else { continue }
                newQueue.remove(at: index)
              }
              if newQueue.isEmpty {
                Task { await vm.player.stop() }
              } else {
                let newIndex = min(vm.player.currentIndex, newQueue.count - 1)
                Task { await vm.player.setQueue(newQueue, startingAt: newIndex) }
              }
            }
            .onMove { source, destination in
              Task { await vm.player.moveQueueItem(from: source, to: destination) }
            }
          }
          .listStyle(.plain)
          .scrollContentBackground(.hidden)
        }
      }
      .background(Color.black)
      .navigationTitle(String(localized: "i18n:Queue.Header", bundle: #bundle))
      #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "i18n:Common.Done", bundle: #bundle)) {
              phoneVM.isQueuePresented = false
            }
          }
          if !vm.player.queue.isEmpty {
            ToolbarItem(placement: .cancellationAction) {
              Button {
                var shuffledQueue = vm.player.queue
                let currentIndex = vm.player.currentIndex
                if currentIndex < shuffledQueue.count {
                  let current = shuffledQueue.remove(at: currentIndex)
                  shuffledQueue.shuffle()
                  shuffledQueue.insert(current, at: 0)
                  Task { await vm.player.setQueue(shuffledQueue, startingAt: 0) }
                }
              } label: {
                Image(systemName: "shuffle")
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

// MARK: - WPAccentColorPicker

/// Phase 78: Accent Color selection sheet — WP signature customization.
struct WPAccentColorPicker: View {
  // MARK: Internal

  var body: some View {
    @Bindable var pvm = phoneVM
    NavigationStack {
      VStack(spacing: 24) {
        Text(String(localized: "i18n:WP.AccentColor.Subtitle", bundle: #bundle))
          .font(.system(size: 15))
          .foregroundStyle(.white.opacity(0.6))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
          .padding(.top, 16)

        // Color grid.
        LazyVGrid(columns: [
          GridItem(.flexible()),
          GridItem(.flexible()),
          GridItem(.flexible()),
        ], spacing: 16) {
          ForEach(WPPhoneViewModel.WPAccentColor.allCases) { accent in
            Button {
              phoneVM.wpAccentColor = accent
            } label: {
              VStack(spacing: 8) {
                Circle()
                  .fill(accent.color)
                  .frame(width: 56, height: 56)
                  .overlay {
                    if accent == phoneVM.wpAccentColor {
                      Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    }
                  }
                Text(verbatim: accent.localizedName)
                  .font(.system(size: 13))
                  .foregroundStyle(.white.opacity(0.7))
              }
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 40)

        Spacer()
      }
      .background(Color.black)
      .navigationTitle(String(localized: "i18n:WP.AccentColor.Title", bundle: #bundle))
      #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "i18n:Common.Done", bundle: #bundle)) {
              phoneVM.isAccentColorPickerPresented = false
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

  @Environment(WPPhoneViewModel.self) private var phoneVM
}
