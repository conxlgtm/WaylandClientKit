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
    name: "WaylandClientKit",
    products: [
        .library(name: "WaylandClient", targets: ["WaylandClient"]),
        .library(name: "WaylandGraphicsPreview", targets: ["WaylandGraphicsPreview"]),
        .executable(name: "wayland-client-kit-smoke", targets: ["WaylandClientKitSmoke"]),
        .executable(name: "wck", targets: ["WaylandClientKitTool"]),
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
            path: "Sources/WaylandGraphicsCore",
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "WaylandGraphicsPreview",
            dependencies: [
                "WaylandClient",
                "WaylandGraphicsCore",
                "WaylandGPUPreview",
                "WaylandRaw",
            ],
            path: "Sources/WaylandGraphicsPreview",
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
            path: "Examples/WaylandExampleSupport",
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "WaylandClientKitToolSupport",
            swiftSettings: librarySwiftSettings
        ),
        .executableTarget(
            name: "WaylandClientKitTool",
            dependencies: [
                "WaylandClientKitToolSupport",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: librarySwiftSettings
        ),
        .executableTarget(
            name: "GraphicsPreviewExternalBufferSmoke",
            dependencies: [
                "CEGLShims",
                "CGBMShims",
                "CGLESv2System",
                "WaylandClient",
                "WaylandExampleSupport",
                "WaylandGraphicsPreview",
            ],
            path: "Examples/GraphicsPreviewExternalBufferSmoke",
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .executableTarget(
            name: "OutputManagementSmoke",
            dependencies: ["WaylandClient", "WaylandExampleSupport"],
            path: "Examples/OutputManagementSmoke",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "GraphicsPreviewManagedGPUClear",
            dependencies: ["WaylandClient", "WaylandExampleSupport", "WaylandGraphicsPreview"],
            path: "Examples/GraphicsPreviewManagedGPUClear",
            swiftSettings: executableSwiftSettings
        ),
        .executableTarget(
            name: "WaylandClientKitSmoke",
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
            name: "WaylandClientKitToolTests",
            dependencies: ["WaylandClientKitToolSupport"],
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: librarySwiftSettings
        ),
        .plugin(
            name: "WckCheckPlugin",
            capability: .command(
                intent: .custom(verb: "wck-check", description: "Run WaylandClientKit checks")
            )
        ),
        .plugin(
            name: "WckReleaseCheckPlugin",
            capability: .command(
                intent: .custom(
                    verb: "wck-release-check",
                    description: "Run WaylandClientKit release checks"
                )
            )
        ),
        .plugin(
            name: "WckGenerateProtocolsPlugin",
            capability: .command(
                intent: .custom(
                    verb: "wck-generate-protocols",
                    description: "Generate Wayland protocols"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Generate protocol artifacts")
                ]
            )
        ),
        .plugin(
            name: "WckVerifyGeneratedPlugin",
            capability: .command(
                intent: .custom(
                    verb: "wck-verify-generated",
                    description: "Verify generated protocols"
                )
            )
        ),
        .plugin(
            name: "WckBootstrapCheckPlugin",
            capability: .command(
                intent: .custom(
                    verb: "wck-bootstrap-check",
                    description: "Verify bootstrap dependencies"
                )
            )
        ),
    ],
    cLanguageStandard: .c17
)
