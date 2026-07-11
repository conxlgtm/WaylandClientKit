// swift-tools-version: 6.3.2
import PackageDescription

let strictSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .strictMemorySafety(),
    .treatWarning("StrictMemorySafety", as: .error),
]

let executableSwiftSettings = strictSwiftSettings + [
    .defaultIsolation(MainActor.self)
]

let package = Package(
    name: "WaylandClientKitExamples",
    dependencies: [
        .package(name: "WaylandClientKit", path: "..")
    ],
    targets: [
        .target(
            name: "WaylandExampleSupport",
            path: "WaylandExampleSupport",
            swiftSettings: strictSwiftSettings
        ),
        .executableTarget(
            name: "WaylandClientKitDemo",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit")],
            path: "WaylandClientKitDemo",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "GPUPreviewSmokeClient",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport", .product(name: "WaylandGraphicsPreview", package: "WaylandClientKit")],
            path: "GPUPreviewSmokeClient",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "GraphicsPreviewColorMetadataSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport", .product(name: "WaylandGraphicsPreview", package: "WaylandClientKit")],
            path: "GraphicsPreviewColorMetadataSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "ColorManagementSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport", .product(name: "WaylandGraphicsPreview", package: "WaylandClientKit")],
            path: "ColorManagementSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "OutputTopologySmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "OutputTopologySmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "FrameworkHostSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit")],
            path: "FrameworkHostSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "PresentationFeedbackAnimation",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "PresentationFeedbackAnimation",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "TwoWindowFrameworkHost",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "TwoWindowFrameworkHost",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "ClientSideResizeChrome",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "ClientSideResizeChrome",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "TextInputSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "TextInputSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "TabletInputSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "TabletInputSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "CompositorSessionSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "CompositorSessionSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "DataTransferSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "DataTransferSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "ToplevelDragSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "ToplevelDragSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "TwoWindowOrderStress",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "TwoWindowOrderStress",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "SerialActionsProbe",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "SerialActionsProbe",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "SessionStateSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "SessionStateSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "XDGActivationSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit")],
            path: "XDGActivationSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "PointerCaptureSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "PointerCaptureSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "PointerGesturesSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "PointerGesturesSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "PointerWarpSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "PointerWarpSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "CursorAnimationSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "CursorAnimationSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "CursorPolicySmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "CursorPolicySmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "CustomCursorSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "CustomCursorSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "WindowIconSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "WindowIconSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "IdleInhibitSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "IdleInhibitSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "DialogSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "DialogSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "KeyboardShortcutsInhibitSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "KeyboardShortcutsInhibitSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "ForeignToplevelListSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "ForeignToplevelListSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "SystemBellSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "SystemBellSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "SurfaceRegionSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "SurfaceRegionSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "DamageRegionSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "DamageRegionSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "SubsurfaceSmoke",
            dependencies: [.product(name: "WaylandClient", package: "WaylandClientKit"), "WaylandExampleSupport"],
            path: "SubsurfaceSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .testTarget(
            name: "WaylandExampleSupportTests",
            dependencies: ["WaylandExampleSupport"],
            path: "WaylandExampleSupportTests",
            swiftSettings: strictSwiftSettings
        ),
    ]
)
