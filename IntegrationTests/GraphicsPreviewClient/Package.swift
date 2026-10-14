// swift-tools-version: 6.4.0
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "WaylandGraphicsPreviewClient",
    dependencies: [
        .package(name: "WaylandClientKit", path: "../..")
    ],
    targets: [
        .testTarget(
            name: "WaylandGraphicsPreviewClientTests",
            dependencies: [
                .product(name: "WaylandClient", package: "WaylandClientKit"),
                .product(name: "WaylandGraphicsPreview", package: "WaylandClientKit"),
            ],
            swiftSettings: swiftSettings
        )
    ],
    cLanguageStandard: .c17
)
