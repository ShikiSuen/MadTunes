// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

/// Overlay that shows an importing spinner (with real-time filename) or an
/// empty-library placeholder when no albums are present.
struct LibraryContentAvailabilityOverlayView: View {
  // MARK: Internal

  let displayAlbums: [Album]

  var body: some View {
    Group {
      if viewModel.library.isImporting {
        VStack(spacing: 8) {
          WinUI3ProgressRing(size: 48, lineWidth: 6)
            .tint(.primary)
          Text("Importing Music…")
          if !viewModel.library.currentProcessingFileName.isEmpty {
            Text(viewModel.library.currentProcessingFileName)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          // Show the "currentlyFinishedFileCount/TotalCount" here with a trailing integer percent.
          if viewModel.library.importTotalFileCount > 0 {
            let finished = viewModel.library.importFinishedFileCount
            let total = viewModel.library.importTotalFileCount
            let percent = total > 0 ? finished * 100 / total : 0
            Text("\(finished)/\(total), ∑\(percent)%")
              .font(.caption)
              .monospacedDigit()
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
      } else if displayAlbums.isEmpty {
        ContentUnavailableView {
          Label("No Music", systemImage: "music.note")
        } description: {
          Text("Import music files or folders to get started.")
        } actions: {
          Button("Import Music") {
            viewModel.isFileImporterPresented = true
          }
          .buttonStyle(.borderedProminent)
          .buttonBorderShape(.capsule)
        }
      }
    }
    .animation(.easeOut(duration: 0.12), value: viewModel.library.isImporting)
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var viewModel
}
