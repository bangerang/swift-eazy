// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "EngineeringMode",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "EngineeringMode",
            targets: ["EngineeringMode"]),
    ],
    dependencies: [
        .package(name: "Eazy", url: "https://github.com/bangerang/swift-eazy.git", .upToNextMajor(from: "0.0.1"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "EngineeringMode",
            dependencies: [.product(name: "Eazy", package: "Eazy")]),
        .testTarget(
            name: "EngineeringModeTests",
            dependencies: ["EngineeringMode"]),
    ]
)
