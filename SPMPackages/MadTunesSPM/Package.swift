// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "MadTunesSPM",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "MadTunesKit",
      targets: ["MadTunesKit"]
    ),
  ],
  targets: [
    .target(name: "MadTunesKit"),
  ]
)
