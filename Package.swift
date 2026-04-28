// swift-tools-version: 6.3.1
import PackageDescription

let librarySwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let executableSwiftSettings: [SwiftSetting] =
    librarySwiftSettings + [
        .defaultIsolation(MainActor.self)
    ]

let package = Package(
    name: "SwiftWayland",
    products: [
        .library(name: "WaylandRaw", targets: ["WaylandRaw"]),
        .library(name: "WaylandClient", targets: ["WaylandClient"]),
        .library(name: "WaylandKeyboardInterpretation", targets: ["WaylandKeyboardInterpretation"]),
        .executable(name: "swift-wayland-demo", targets: ["SwiftWaylandDemo"]),
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
        .target(
            name: "CWaylandProtocols",
            dependencies: ["CWaylandClientSystem"],
            publicHeadersPath: "include",
            cSettings: [
                .define("_GNU_SOURCE", .when(platforms: [.linux]))
            ]
        ),
        .target(
            name: "WaylandRaw",
            dependencies: ["CWaylandProtocols", "CWaylandClientSystem"],
            swiftSettings: librarySwiftSettings
        ),
        .target(
            name: "WaylandClient",
            dependencies: ["WaylandRaw"],
            swiftSettings: librarySwiftSettings
        ),
        .target(
            name: "WaylandKeyboardInterpretation",
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
            name: "WaylandClientTests",
            dependencies: ["WaylandClient"],
            swiftSettings: librarySwiftSettings
        ),
        .testTarget(
            name: "WaylandKeyboardInterpretationTests",
            dependencies: ["WaylandKeyboardInterpretation"],
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: librarySwiftSettings
        ),
        .testTarget(
            name: "WaylandSmokeSupportTests",
            dependencies: ["WaylandSmokeSupport"],
            swiftSettings: librarySwiftSettings
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["WaylandClient"],
            swiftSettings: librarySwiftSettings
        ),
    ],
    cLanguageStandard: .c17
)
