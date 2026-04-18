// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Wayforge",
    products: [
        .library(name: "WaylandRaw", targets: ["WaylandRaw"]),
        .library(name: "WaylandClient", targets: ["WaylandClient"]),
        .executable(name: "wayforge-demo", targets: ["WayforgeDemo"]),
    ],
    targets: [
        .systemLibrary(
            name: "CWaylandClientSystem",
            pkgConfig: "wayland-client"
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
            dependencies: ["CWaylandProtocols", "CWaylandClientSystem"]
        ),
        .target(
            name: "WaylandClient",
            dependencies: ["WaylandRaw"]
        ),
        .executableTarget(
            name: "WayforgeDemo",
            dependencies: ["WaylandClient"]
        ),
        .testTarget(
            name: "WaylandRawTests",
            dependencies: ["WaylandRaw"]
        ),
        .testTarget(
            name: "WaylandClientTests",
            dependencies: ["WaylandClient"]
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["WaylandClient"]
        ),
    ],
    cLanguageStandard: .c17
)
