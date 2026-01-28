// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PRTracker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "PRTracker",
            targets: ["PRTracker"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/nerdishbynature/octokit.swift.git", from: "0.13.0")
    ],
    targets: [
        .executableTarget(
            name: "PRTracker",
            dependencies: [
                .product(name: "OctoKit", package: "octokit.swift")
            ],
            path: "Sources/PRTracker"
        )
    ]
)
