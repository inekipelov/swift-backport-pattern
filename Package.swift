// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-backport",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v9),
        .tvOS(.v9),
        .watchOS(.v2)
    ],
    products: [
        .library(
            name: "Backport",
            targets: ["Backport"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Backport",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "BackportTests",
            dependencies: ["Backport"],
            path: "Tests"),
    ]
)