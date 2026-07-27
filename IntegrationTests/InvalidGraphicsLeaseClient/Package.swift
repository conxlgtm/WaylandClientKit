// swift-tools-version: 6.3.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "InvalidGraphicsLeaseClient",
    dependencies: [
        .package(name: "WaylandClientKit", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "FrameLeaseCopyClient",
            dependencies: [
                .product(name: "WaylandGraphicsPreview", package: "WaylandClientKit")
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "FrameLeaseTransferClient",
            dependencies: [
                .product(name: "WaylandGraphicsPreview", package: "WaylandClientKit")
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "RenderLeaseCopyClient",
            dependencies: [
                .product(name: "WaylandGraphicsPreview", package: "WaylandClientKit")
            ],
            swiftSettings: swiftSettings
        ),
    ]
)
