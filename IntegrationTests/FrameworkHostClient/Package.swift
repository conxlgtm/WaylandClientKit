// swift-tools-version: 6.3.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "WaylandFrameworkHostClient",
    dependencies: [
        .package(name: "WaylandClientKit", path: "../..")
    ],
    targets: [
        .testTarget(
            name: "WaylandFrameworkHostClientTests",
            dependencies: [
                .product(name: "WaylandClient", package: "WaylandClientKit"),
                .product(name: "WaylandGraphicsPreview", package: "WaylandClientKit"),
            ],
            swiftSettings: swiftSettings
        )
    ],
    cLanguageStandard: .c17
)
