// swift-tools-version: 6.3.1
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

let executableSwiftSettings: [SwiftSetting] =
    strictMemorySafetySwiftSettings + [
        .defaultIsolation(MainActor.self)
    ]

let runtimeSwiftSettings: [SwiftSetting] =
    strictMemorySafetySwiftSettings + [
        .define("ENABLE_TESTING", .when(configuration: .debug))
    ]

let package = Package(
    name: "SwiftWayland",
    products: [
        .library(name: "WaylandClient", targets: ["WaylandClient"]),
        .executable(name: "swift-wayland-smoke", targets: ["SwiftWaylandSmoke"]),
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
        .target(
            name: "CWaylandCursorShims",
            dependencies: ["CWaylandCursorSystem"],
            publicHeadersPath: "include",
            cSettings: [
                .define("_GNU_SOURCE", .when(platforms: [.linux]))
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
            name: "WaylandGraphicsPreview",
            dependencies: ["WaylandRaw"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .target(
            name: "WaylandSmokeSupport",
            dependencies: ["WaylandClient"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .executableTarget(
            name: "SwiftWaylandDemo",
            dependencies: ["WaylandClient"],
            path: "Examples/SwiftWaylandDemo",
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
            dependencies: ["WaylandRaw", "WaylandTestSupport", "CDRMSystem", "CGBMSystem"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .testTarget(
            name: "WaylandRuntimeTests",
            dependencies: ["WaylandRaw", "WaylandRuntime"],
            swiftSettings: strictMemorySafetySwiftSettings
        ),
        .testTarget(
            name: "WaylandClientTests",
            dependencies: [
                "WaylandClient",
                "WaylandKeyboard",
                "CWaylandProtocols",
                "WaylandTestSupport",
            ],
            swiftSettings: strictMemorySafetySwiftSettings
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
            dependencies: ["WaylandGraphicsPreview", "WaylandRaw"],
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
    ],
    cLanguageStandard: .c17
)
