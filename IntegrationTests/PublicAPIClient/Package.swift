// swift-tools-version: 6.3.1
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "WaylandPublicIntegrationClient",
    dependencies: [
        .package(name: "SwiftWayland", path: "../..")
    ],
    targets: [
        .testTarget(
            name: "WaylandPublicIntegrationClientTests",
            dependencies: [
                .product(name: "WaylandClient", package: "SwiftWayland")
            ],
            swiftSettings: swiftSettings
        )
    ],
    cLanguageStandard: .c17
)
