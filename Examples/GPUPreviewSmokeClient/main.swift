import Foundation
import WaylandClient
import WaylandGraphicsPreview

@main
struct GPUPreviewSmokeClient {
    static func main() async throws {
        try await WaylandDisplay.withConnection { display in
            let backing = try await display.createGraphicsWindowBacking(
                windowConfiguration: WindowConfiguration(
                    title: "SwiftWayland Graphics Preview",
                    appID: "swift-wayland-graphics-preview",
                    initialWidth: 96,
                    initialHeight: 96,
                    bufferCount: 2
                )
            )
            let lease = try await backing.nextFrame()
            try await lease.submit(
                .clearColor(
                    WaylandGraphicsXRGBColor(red: 0x3F, green: 0x80, blue: 0xFF)
                )
            )
            let runtimePath = try await backing.runtimePath
            try await backing.close()
            printReport(runtimePath: runtimePath)
        }
    }

    nonisolated private static func printReport(
        runtimePath: WaylandGraphicsRuntimePath
    ) {
        let capabilities = runtimePath.capabilities
        print("SwiftWayland GPU Preview Runtime Path")
        print("display: \(displayName())")
        print("compositor: unknown")
        print("window: software clear submitted")
        print(
            "dmabuf: \(availability(capabilities.dmabuf)), runtime \(status(runtimePath.dmabuf))"
        )
        print("gbm: \(status(runtimePath.gbm))")
        print("egl: \(status(runtimePath.egl))")
        print(
            """
            explicit-sync: \(availability(capabilities.explicitSync)), \
            runtime \(status(runtimePath.explicitSync))
            """
        )
        print(
            """
            pacing: fifo \(availability(capabilities.framePacing.fifo)), \
            commit-timing \(availability(capabilities.framePacing.commitTiming))
            """
        )
        print(
            """
            metadata: content-type \(availability(capabilities.colorMetadata.contentType)), \
            alpha-modifier \(availability(capabilities.colorMetadata.alphaModifier)), \
            tearing-control \(availability(capabilities.colorMetadata.tearingControl)), \
            color-representation \(availability(capabilities.colorMetadata.colorRepresentation)), \
            color-management \(availability(capabilities.colorMetadata.colorManagement))
            """
        )
        print("presentation: \(status(runtimePath.presentationFeedback))")
        print("backing: \(backing(runtimePath))")
    }

    nonisolated private static func displayName() -> String {
        ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] ?? "unset"
    }

    nonisolated private static func availability(
        _ availability: WaylandGraphicsProtocolAvailability
    ) -> String {
        switch availability {
        case .unavailable:
            "unavailable"
        case .pending(let version):
            "pending v\(version)"
        case .available(let version):
            "advertised v\(version)"
        }
    }

    nonisolated private static func status(
        _ status: WaylandGraphicsRuntimeStatus
    ) -> String {
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
        case .failed(let reason):
            "failed(\(reason))"
        case .fallback(let reason):
            "fallback(\(reason))"
        }
    }

    nonisolated private static func backing(_ path: WaylandGraphicsRuntimePath) -> String {
        switch path.backing {
        case .active:
            "gpu active"
        case .configured:
            "gpu configured"
        case .advertised:
            "gpu projected"
        case .fallback(let reason):
            "software fallback(\(reason))"
        case .failed(let reason):
            "unavailable(\(reason))"
        case .pending:
            "pending"
        case .unavailable:
            "unavailable"
        }
    }
}
