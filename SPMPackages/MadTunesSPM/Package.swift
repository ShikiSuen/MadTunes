// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "MadTunesSPM",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "MadTunesKit",
      targets: ["MadTunesKit"]
    ),
  ],
  targets: [
    .target(
      name: "MadTunesKit",
      resources: [
        .process("./Resources"),
      ]
    ),
    .testTarget(
      name: "MadTunesKitTests",
      dependencies: ["MadTunesKit"],
      swiftSettings: [
        // 為了防止不同的測試用例在執行過程中互相干擾，故強制 MainActor 順序執行。
        .defaultIsolation(MainActor.self),
      ]
    ),
  ]
)
