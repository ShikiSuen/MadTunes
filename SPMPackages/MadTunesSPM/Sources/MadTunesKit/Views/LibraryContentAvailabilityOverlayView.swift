// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI
import simd

/// Overlay that shows an importing spinner (with real-time filename) or an
/// empty-library placeholder when no albums are present.
struct LibraryContentAvailabilityOverlayView: View {
  // MARK: Internal

  let displayAlbums: [Album]

  var body: some View {
    Group {
      if viewModel.library.isImporting {
        VStack(spacing: 8) {
          let hasFileImporting = viewModel.library.importTotalFileCount > 0
          let finished = viewModel.library.importFinishedFileCount
          let total = viewModel.library.importTotalFileCount
          let percent = total > 0 ? finished * 100 / total : 0
          WinUI3ProgressRing(size: 64, lineWidth: 7)
            .tint(.primary)
            .overlay {
              if hasFileImporting {
                Text(verbatim: "\(percent)%")
                  .font(.title)
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
              }
            }
          Text("Importing Music…")
          if !viewModel.library.currentProcessingFileName.isEmpty {
            Text(viewModel.library.currentProcessingFileName)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          // Show the "currentlyFinishedFileCount/TotalCount" here with a trailing integer percent.
          if hasFileImporting {
            Text("\(finished)/\(total)")
              .font(.caption)
              .monospacedDigit()
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
          backgroundColorMesh
          .ignoresSafeArea()
        }
        .compositingGroup()
      } else if displayAlbums.isEmpty {
        backgroundColorMesh
        .ignoresSafeArea()
        .overlay {
          ContentUnavailableView {
            Label("No Music", systemImage: "music.note")
          } description: {
            Text("Import music files or folders to get started.")
          } actions: {
            switch OS.isAppKit {
            case true:
              Button("Import Files / Folders…") {
                viewModel.isFolderImporterPresented = true
              }
              .buttonStyle(.borderedProminent)
              .buttonBorderShape(.capsule)
            case false:
              Button("Import Files…") {
                viewModel.isFileImporterPresented = true
              }
              .buttonStyle(.borderedProminent)
              .buttonBorderShape(.capsule)
              Button("Import Folder…") {
                viewModel.isFolderImporterPresented = true
              }
              .buttonStyle(.borderedProminent)
              .buttonBorderShape(.capsule)
            }
          }
        }
        .compositingGroup()
      }
    }
    .animation(.easeOut(duration: 0.12), value: viewModel.library.isImporting)
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var viewModel
  @State private var currentProcessingFileName: String = ""
  @State private var currentProcessingFileCount: Int = 0

  private var angularColorGradient: AngularGradient {
    AngularGradient(
      gradient: Gradient(stops: [
        .init(color: Color(hue: 3 / 6, saturation: 1, brightness: 1), location: 0.0 / 6),
        .init(color: Color(hue: 4 / 6, saturation: 1, brightness: 1), location: 1.0 / 6),
        .init(color: Color(hue: 5 / 6, saturation: 1, brightness: 1), location: 2.0 / 6),
        .init(color: Color(hue: 6 / 6, saturation: 1, brightness: 1), location: 3.0 / 6),
        .init(color: Color(hue: 0 / 6, saturation: 1, brightness: 1), location: 4.0 / 6),
        .init(color: Color(hue: 1 / 6, saturation: 1, brightness: 1), location: 5.0 / 6),
        .init(color: Color(hue: 2 / 6, saturation: 1, brightness: 1), location: 1.0),
      ]),
      center: .center
    )
  }

  @ViewBuilder private var backgroundColorMesh: some View {
      Group {
        if #available(macOS 15.0, *) {
          MeshGradient(
            width: 2,
            height: 2,
            points: [
              SIMD2(0.0, 0.0), // Top-left
              SIMD2(1.0, 0.0), // Top-right
              SIMD2(0.0, 1.0), // Bottom-left
              SIMD2(1.0, 1.0)  // Bottom-right
            ],
            colors: [
              .red,
              .blue,
              .green,
              .purple
            ]
          )
          .opacity(0.3)
          .background {
            Color.primary.colorInvert()
          }
        } else {
          angularColorGradient
            .blur(radius: 8)
            .opacity(0.3)
            .background {
              Color.primary.colorInvert()
            }
        }
      }
  }
}
