// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "DisplayLink",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macOS(.v10_15),
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
