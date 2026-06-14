import Foundation
import WaylandClient
import WaylandExampleSupport
import WaylandGraphicsPreview

@main
enum ColorManagementSmoke {
    static func main() async throws {
        _ = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection { display in
            let backing = try await display.createGraphicsWindowBacking(
                windowConfiguration: WindowConfiguration(
                    title: "WaylandClientKit Color Management Smoke",
                    appID: "wayland-client-kit-color-management-smoke",
                    initialWidth: 96,
                    initialHeight: 96,
                    bufferCount: 2
                ),
                graphicsConfiguration: WaylandGraphicsConfiguration(
                    metadataPolicy: .preferAvailable
                )
            )
            let runtimePath = try await backing.runtimePath

            log("feature: color-management")
            log(
                "capability: color management \(availability(runtimePath.capabilities.colorMetadata.colorManagement))"
            )
            log(
                "capability: color representation \(availability(runtimePath.capabilities.colorMetadata.colorRepresentation))"
            )
            log(
                "metadata color representation: \(status(runtimePath.metadata.colorRepresentation))"
            )
            log("metadata color management: \(status(runtimePath.metadata.colorManagement))")
            log("metadata alpha modifier: \(status(runtimePath.metadata.alphaModifier))")
            log("cleanup: pass")
            try await backing.close()
        }
    }

    nonisolated private static func availability(
        _ availability: WaylandGraphicsProtocolAvailability
    ) -> String {
        switch availability {
        case .available(let version):
            "advertised v\(version)"
        case .pending(let version):
            "pending v\(version)"
        case .unavailable:
            "unavailable"
        }
    }

    nonisolated private static func status(_ status: WaylandGraphicsRuntimeStatus) -> String {
        switch status {
        case .unavailable:
            "unavailable"
        case .pending:
            "pending"
        case .advertised:
            "advertised"
        case .configured:
            "configured"
        case .active:
            "active"
        case .fallback(let reason):
            "fallback(\(reason))"
        case .failed(let reason):
            "failed(\(reason))"
        }
    }

    nonisolated private static func log(_ message: String) {
        print(message)
    }
}
