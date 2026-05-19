// swift-tools-version: 6.3.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "WaylandGraphicsPreviewClient",
    dependencies: [
        .package(name: "SwiftWayland", path: "../..")
    ],
    targets: [
        .testTarget(
            name: "WaylandGraphicsPreviewClientTests",
            dependencies: [
                .product(name: "WaylandClient", package: "SwiftWayland"),
                .product(name: "WaylandGraphicsPreview", package: "SwiftWayland"),
            ],
            swiftSettings: swiftSettings
        )
    ],
    cLanguageStandard: .c17
)
