// swift-tools-version: 6.3.2
import PackageDescription

let librarySwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let strictMemorySafetySwiftSettings: [SwiftSetting] =
    librarySwiftSettings + [
        .strictMemorySafety(),
        .treatWarning("StrictMemorySafety", as: .error),
    ]

let cShimTestingSwiftSettings: [SwiftSetting] =
    strictMemorySafetySwiftSettings + [
        .define("SWL_ENABLE_TESTING", .when(configuration: .debug)),
        .unsafeFlags(["-Xcc", "-DSWL_ENABLE_TESTING"], .when(configuration: .debug)),
    ]

let executableSwiftSettings: [SwiftSetting] =
    strictMemorySafetySwiftSettings + [
        .defaultIsolation(MainActor.self)
    ]

let runtimeSwiftSettings: [SwiftSetting] =
    strictMemorySafetySwiftSettings + [
        .define("ENABLE_TESTING", .when(configuration: .debug))
    ]

let runtimeTestingSwiftSettings: [SwiftSetting] =
    strictMemorySafetySwiftSettings + [
        .define("ENABLE_TESTING", .when(configuration: .debug))
    ]

let package = Package(
    name: "SwiftWayland",
    products: [
        .library(name: "WaylandClient", targets: ["WaylandClient"]),
        .library(name: "WaylandGraphicsPreview", targets: ["WaylandGraphicsPreview"]),
        .executable(name: "swift-wayland-smoke", targets: ["SwiftWaylandSmoke"]),
        .executable(name: "swl", targets: ["SwiftWaylandTool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.0")
    ],
    targets: [
        .systemLibrary(
            name: "CWaylandClientSystem",
            pkgConfig: "wayland-client"
        ),
        .systemLibrary(
            name: "CXKBCommonSystem",
            pkgConfig: "xkbcommon"
        ),
        .systemLibrary(
            name: "CWaylandCursorSystem",
            pkgConfig: "wayland-cursor"
        ),
        .systemLibrary(
            name: "CDRMSystem",
            pkgConfig: "libdrm"
        ),
        .systemLibrary(
            name: "CGBMSystem",
            pkgConfig: "gbm"
        ),
        .systemLibrary(
            name: "CEGLSystem",
            pkgConfig: "egl"
        ),
        .systemLibrary(
            name: "CGLESv2System",
            pkgConfig: "glesv2"
        ),
        .target(
            name: "CWaylandCursorShims",
            dependencies: ["CWaylandCursorSystem"],
            publicHeadersPath: "include",
            cSettings: [
                .define("_GNU_SOURCE", .when(platforms: [.linux]))
            ]
        ),
        .target(
            name: "CGBMShims",
            dependencies: ["CGBMSystem", "CDRMSystem"],
            publicHeadersPath: "include",
            cSettings: [
                .define("SWL_ENABLE_TESTING", .when(configuration: .debug)),
                .define("_GNU_SOURCE", .when(platforms: [.linux])),
            ]
        ),
        .target(
            name: "CEGLShims",
            dependencies: ["CEGLSystem", "CGLESv2System", "CGBMSystem"],
            publicHeadersPath: "include",
            cSettings: [
                .define("SWL_ENABLE_TESTING", .when(configuration: .debug)),
                .define("_GNU_SOURCE", .when(platforms: [.linux])),
            ]
        ),
        .target(
            name: "WaylandCursor",
            dependencies: ["WaylandRaw", "CWaylandCursorShims"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "CWaylandProtocols",
            dependencies: ["CWaylandClientSystem"],
            publicHeadersPath: "include",
            cSettings: [
                .define("SWL_ENABLE_TESTING", .when(configuration: .debug)),
                .define("_GNU_SOURCE", .when(platforms: [.linux])),
            ]
        ),
        .target(
            name: "WaylandRaw",
            dependencies: ["CWaylandProtocols", "CWaylandClientSystem", "CWaylandRuntimeShims"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "CWaylandRuntimeShims",
            publicHeadersPath: "include",
            cSettings: [
                .define("_GNU_SOURCE", .when(platforms: [.linux]))
            ]
        ),
        .target(
            name: "WaylandRuntime",
            dependencies: ["CWaylandRuntimeShims", "CWaylandClientSystem", "WaylandRaw"],
            swiftSettings: runtimeSwiftSettings
        ),
        .target(
            name: "WaylandClient",
            dependencies: [
                "WaylandRaw",
                "WaylandRuntime",
                "WaylandKeyboard",
                "WaylandCursor",
            ],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "WaylandKeyboard",
            dependencies: ["WaylandRaw", "CXKBCommonSystem"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "WaylandGraphicsCore",
            dependencies: ["WaylandRaw", "CGBMShims", "CEGLShims", "CDRMSystem"],
            path: "Sources/WaylandGraphicsPreview",
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "WaylandGraphicsPreview",
            dependencies: ["WaylandClient", "WaylandGPUPreview", "WaylandRaw"],
            path: "Sources/WaylandGraphicsPreviewAPI",
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "WaylandGPUPreview",
            dependencies: ["WaylandClient", "WaylandGraphicsCore", "WaylandRaw"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "WaylandSmokeSupport",
            dependencies: ["WaylandClient"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "WaylandExampleSupport",
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "SwiftWaylandToolSupport",
            swiftSettings: librarySwiftSettings
        ),
        .executableTarget(
            name: "SwiftWaylandTool",
            dependencies: [
                "SwiftWaylandToolSupport",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: librarySwiftSettings
        ),
        .executableTarget(
            name: "SwiftWaylandDemo",
            dependencies: ["WaylandClient"],
            path: "Examples/SwiftWaylandDemo",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "GPUPreviewSmokeClient",
            dependencies: ["WaylandClient", "WaylandGraphicsPreview"],
            path: "Examples/GPUPreviewSmokeClient",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "GraphicsPreviewManagedGPUClear",
            dependencies: ["WaylandClient", "WaylandExampleSupport", "WaylandGraphicsPreview"],
            path: "Examples/GraphicsPreviewManagedGPUClear",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "FrameworkHostSmoke",
            dependencies: ["WaylandClient"],
            path: "Examples/FrameworkHostSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "PresentationFeedbackAnimation",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/PresentationFeedbackAnimation",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "TwoWindowFrameworkHost",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/TwoWindowFrameworkHost",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "ClientSideResizeChrome",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/ClientSideResizeChrome",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "TextInputSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/TextInputSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "DataTransferSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/DataTransferSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "TwoWindowOrderStress",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/TwoWindowOrderStress",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "SerialActionsProbe",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/SerialActionsProbe",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "SessionStateSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/SessionStateSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "XDGActivationSmoke",
            dependencies: ["WaylandClient"],
            path: "Examples/XDGActivationSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "PointerCaptureSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/PointerCaptureSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "CursorPolicySmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/CursorPolicySmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "CustomCursorSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/CustomCursorSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "WindowIconSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/WindowIconSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "IdleInhibitSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/IdleInhibitSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "SystemBellSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/SystemBellSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "SurfaceRegionSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/SurfaceRegionSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "DamageRegionSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/DamageRegionSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "SubsurfaceSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/SubsurfaceSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "SwiftWaylandSmoke",
            dependencies: ["WaylandSmokeSupport"],
            swiftSettings: executableSwiftSettings
        ),
        .target(
            name: "WaylandTestSupport",
            path: "Tests/WaylandTestSupport",
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .testTarget(
            name: "WaylandRawTests",
            dependencies: [
                "WaylandRaw",
                "WaylandTestSupport",
                "CDRMSystem",
                "CGBMSystem",
                "CEGLSystem",
                "CGLESv2System",
            ],
            swiftSettings: cShimTestingSwiftSettings
        ),
        .testTarget(
            name: "WaylandRuntimeTests",
            dependencies: ["WaylandRaw", "WaylandRuntime"],
            swiftSettings: runtimeTestingSwiftSettings
        ),
        .testTarget(
            name: "WaylandClientTests",
            dependencies: [
                "WaylandClient",
                "WaylandKeyboard",
                "CWaylandProtocols",
                "WaylandTestSupport",
            ],
            swiftSettings: cShimTestingSwiftSettings
        ),
        .testTarget(
            name: "WaylandKeyboardTests",
            dependencies: ["WaylandKeyboard"],
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .testTarget(
            name: "WaylandGraphicsPreviewTests",
            dependencies: [
                "WaylandGraphicsCore",
                "WaylandRaw",
                "CGBMShims",
                "CEGLShims",
            ],
            swiftSettings: cShimTestingSwiftSettings
        ),
        .testTarget(
            name: "WaylandGraphicsPreviewAPITests",
            dependencies: ["WaylandGraphicsPreview", "WaylandClient", "WaylandRaw"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .testTarget(
            name: "WaylandGPUPreviewTests",
            dependencies: [
                "WaylandGPUPreview",
                "WaylandGraphicsCore",
                "WaylandGraphicsPreview",
                "WaylandClient",
            ],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .testTarget(
            name: "WaylandCursorTests", dependencies: ["WaylandCursor"],
            swiftSettings: strictMemorySafetySwiftSettings),
        .testTarget(
            name: "WaylandSmokeSupportTests",
            dependencies: ["WaylandSmokeSupport"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .testTarget(
            name: "WaylandExampleSupportTests",
            dependencies: ["WaylandExampleSupport"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .testTarget(
            name: "SwiftWaylandToolTests",
            dependencies: ["SwiftWaylandToolSupport"],
            swiftSettings: librarySwiftSettings
        ),
        .plugin(
            name: "SwlCheckPlugin",
            capability: .command(
                intent: .custom(verb: "swl-check", description: "Run SwiftWayland checks")
            )
        ),
        .plugin(
            name: "SwlReleaseCheckPlugin",
            capability: .command(
                intent: .custom(
                    verb: "swl-release-check",
                    description: "Run SwiftWayland release checks"
                )
            )
        ),
        .plugin(
            name: "SwlGenerateProtocolsPlugin",
            capability: .command(
                intent: .custom(
                    verb: "swl-generate-protocols",
                    description: "Generate Wayland protocols"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Generate protocol artifacts")
                ]
            )
        ),
        .plugin(
            name: "SwlVerifyGeneratedPlugin",
            capability: .command(
                intent: .custom(
                    verb: "swl-verify-generated",
                    description: "Verify generated protocols"
                )
            )
        ),
        .plugin(
            name: "SwlBootstrapCheckPlugin",
            capability: .command(
                intent: .custom(
                    verb: "swl-bootstrap-check",
                    description: "Verify bootstrap dependencies"
                )
            )
        ),
    ],
    cLanguageStandard: .c17
)
