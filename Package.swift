// swift-tools-version: 6.3.1
import PackageDescription

let librarySwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let publicClientSwiftSettings: [SwiftSetting] =
    librarySwiftSettings + [
        .strictMemorySafety(),
        .treatWarning("StrictMemorySafety", as: .error),
    ]

let executableSwiftSettings: [SwiftSetting] =
    librarySwiftSettings + [
        .defaultIsolation(MainActor.self)
    ]

let runtimeSwiftSettings: [SwiftSetting] =
    librarySwiftSettings + [
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
            swiftSettings: librarySwiftSettings
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
            swiftSettings: librarySwiftSettings
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
            swiftSettings: publicClientSwiftSettings
        ),
        .target(
            name: "WaylandKeyboard",
            dependencies: ["WaylandRaw", "CXKBCommonSystem"],
            swiftSettings: librarySwiftSettings
        ),
        .target(
            name: "WaylandSmokeSupport",
            dependencies: ["WaylandClient"],
            swiftSettings: librarySwiftSettings
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
        .testTarget(
            name: "WaylandRawTests",
            dependencies: ["WaylandRaw"],
            swiftSettings: librarySwiftSettings
        ),
        .testTarget(
            name: "WaylandRuntimeTests",
            dependencies: ["WaylandRaw", "WaylandRuntime"],
            swiftSettings: librarySwiftSettings
        ),
        .testTarget(
            name: "WaylandClientTests",
            dependencies: ["WaylandClient", "WaylandKeyboard"],
            swiftSettings: librarySwiftSettings
        ),
        .testTarget(
            name: "WaylandKeyboardTests",
            dependencies: ["WaylandKeyboard"],
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: librarySwiftSettings
        ),
        .testTarget(
            name: "WaylandCursorTests", dependencies: ["WaylandCursor"],
            swiftSettings: librarySwiftSettings),
        .testTarget(
            name: "WaylandSmokeSupportTests",
            dependencies: ["WaylandSmokeSupport"],
            swiftSettings: librarySwiftSettings
        ),
    ],
    cLanguageStandard: .c17
)
