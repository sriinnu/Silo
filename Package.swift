// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Silo",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .linux,
        .windows(.v10),
    ],
    products: [
        .library(name: "Silo", targets: ["Silo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "Silo",
            path: "Sources/Silo",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]),
        .testTarget(
            name: "SiloTests",
            dependencies: ["Silo"],
            path: "Tests/SiloTests"),
    ],
    swiftLanguageModes: [.v6])
