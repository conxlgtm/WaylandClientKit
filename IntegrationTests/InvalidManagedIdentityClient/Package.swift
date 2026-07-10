// swift-tools-version: 6.3.2
import PackageDescription

let targets = [
    "DiagnosticIDClient",
    "ForeignToplevelIDClient",
    "OutputHeadIDClient",
    "OutputModeIDClient",
    "PointerConstraintIDClient",
    "PointerGestureIDClient",
    "PresentationIdentityClient",
    "RelativePointerIDClient",
]

let package = Package(
    name: "InvalidManagedIdentityClient",
    dependencies: [
        .package(name: "WaylandClientKit", path: "../..")
    ],
    targets: targets.map { name in
        .executableTarget(
            name: name,
            dependencies: [
                .product(name: "WaylandClient", package: "WaylandClientKit")
            ]
        )
    }
)
