// swift-tools-version: 6.4.0
import PackageDescription

let package = Package(
    name: "InvalidGraphicsPolicyClient",
    dependencies: [
        .package(name: "WaylandClientKit", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "InvalidGraphicsPolicyClient",
            dependencies: [
                .product(name: "WaylandGraphicsPreview", package: "WaylandClientKit")
            ]
        )
    ]
)
