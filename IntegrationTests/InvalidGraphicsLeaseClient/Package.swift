// swift-tools-version: 6.4.0
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
        .executableTarget(
            name: "FrameLeaseBorrowCancelClient",
            dependencies: [.product(name: "WaylandGraphicsPreview", package: "WaylandClientKit")],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "FrameLeaseBorrowSubmitClient",
            dependencies: [.product(name: "WaylandGraphicsPreview", package: "WaylandClientKit")],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "RenderLeaseBorrowCancelClient",
            dependencies: [.product(name: "WaylandGraphicsPreview", package: "WaylandClientKit")],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "RenderLeaseBorrowSubmitClient",
            dependencies: [.product(name: "WaylandGraphicsPreview", package: "WaylandClientKit")],
            swiftSettings: swiftSettings
        ),
    ]
)
