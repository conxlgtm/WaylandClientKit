import Foundation

public struct ExampleBuilder {
    public static let targets = [
        "ClientSideResizeChrome",
        "CursorPolicySmoke",
        "CustomCursorSmoke",
        "DamageRegionSmoke",
        "DataTransferSmoke",
        "FrameworkHostSmoke",
        "GPUPreviewSmokeClient",
        "GraphicsPreviewManagedGPUClear",
        "IdleInhibitSmoke",
        "PointerCaptureSmoke",
        "PresentationFeedbackAnimation",
        "SerialActionsProbe",
        "SubsurfaceSmoke",
        "SurfaceRegionSmoke",
        "SwiftWaylandDemo",
        "SystemBellSmoke",
        "TextInputSmoke",
        "TwoWindowFrameworkHost",
        "TwoWindowOrderStress",
        "WindowIconSmoke",
        "XDGActivationSmoke",
    ]

    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    public func buildAll(configurations: [String] = ["debug", "release"]) throws {
        for configuration in configurations {
            for target in Self.targets {
                try context.swift.runSwift(
                    [
                        "build",
                        "--disable-index-store",
                        "-c",
                        configuration,
                        "--target",
                        target,
                    ],
                    repository: context.repository)
            }
        }
        context.diagnostics.success(
            "example targets build in \(configurations.joined(separator: "/"))")
    }
}
