// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MajorSystemKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MajorSystemKit",
            targets: ["MajorSystemKit"]
        )
    ],
    targets: [
        .target(
            name: "MajorSystemKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MajorSystemKitTests",
            dependencies: ["MajorSystemKit"]
        )
    ]
)
