// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Eazy",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "Eazy",
            targets: ["Eazy"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", .exact("0.4.0"))
    ],
    targets: [
        .target(
            name: "Eazy",
            dependencies: [.product(name: "CustomDump", package: "swift-custom-dump")]),
        .testTarget(
            name: "EazyTests",
            dependencies: ["Eazy"]),
    ]
)
