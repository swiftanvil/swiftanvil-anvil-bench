// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BenchmarkKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "BenchmarkKit",
            targets: ["BenchmarkKit"]
        ),
        .library(
            name: "BenchmarkKitSwiftUI",
            targets: ["BenchmarkKitSwiftUI"]
        )
    ],
    targets: [
        .target(name: "BenchmarkKit"),
        .target(
            name: "BenchmarkKitSwiftUI",
            dependencies: ["BenchmarkKit"]
        ),
        .testTarget(
            name: "BenchmarkKitTests",
            dependencies: ["BenchmarkKit"]
        ),
        .testTarget(
            name: "BenchmarkKitSwiftUITests",
            dependencies: ["BenchmarkKit", "BenchmarkKitSwiftUI"]
        )
    ],
    swiftLanguageModes: [.v6]
)
