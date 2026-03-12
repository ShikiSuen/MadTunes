// swift-tools-version: 6.1

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
  ]
)
