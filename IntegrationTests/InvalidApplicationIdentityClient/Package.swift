// swift-tools-version: 6.3.2
import PackageDescription

let package = Package(
    name: "InvalidApplicationIdentityClient",
    dependencies: [
        .package(name: "WaylandClientKit", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "InvalidApplicationIdentityClient",
            dependencies: [
                .product(name: "WaylandClient", package: "WaylandClientKit")
            ]
        )
    ]
)
