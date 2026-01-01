// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SweetCookieKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .linux,
        .windows(.v10),
    ],
    products: [
        .library(name: "SweetCookieKit", targets: ["SweetCookieKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "SweetCookieKit",
            path: "Sources/SweetCookieKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]),
        .testTarget(
            name: "SweetCookieKitTests",
            dependencies: ["SweetCookieKit"],
            path: "Tests/SweetCookieKitTests"),
    ],
    swiftLanguageModes: [.v6])
