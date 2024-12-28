// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DisplayLink",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "DisplayLink",
            targets: ["DisplayLink"]),
    ],
    targets: [
        .target(
            name: "DisplayLink",
            dependencies: []),
      ]
)
