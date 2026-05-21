import Foundation
import WaylandClient
import WaylandGraphicsPreview

@main
struct GPUPreviewSmokeClient {
    static func main() async throws {
        try await WaylandDisplay.withConnection { display in
            let runtimePath = try await display.graphicsRuntimePath()
            let backingDecision = try await display.graphicsBackingDecision()

            let window = try await display.createTopLevelWindow(
                configuration: WindowConfiguration(
                    title: "SwiftWayland Graphics Preview",
                    appID: "swift-wayland-graphics-preview",
                    initialWidth: 96,
                    initialHeight: 96,
                    bufferCount: 2
                )
            )
            try await window.show { frame in
                clear(frame)
            }
            await window.close()
            printReport(runtimePath: runtimePath, backingDecision: backingDecision)
        }
    }

    nonisolated private static func clear(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for column in 0..<pixels.count {
                let red = UInt32((column * 255) / max(pixels.count, 1))
                let blue = UInt32((row * 255) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: column] = (red << 16) | 0x3F00 | blue
            }
        }
    }

    nonisolated private static func printReport(
        runtimePath: WaylandGraphicsRuntimePath,
        backingDecision: WaylandGraphicsBackingDecision
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
        print("backing: \(backing(backingDecision))")
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

    nonisolated private static func backing(
        _ decision: WaylandGraphicsBackingDecision
    ) -> String {
        switch decision {
        case .gpu(let path):
            "gpu \(status(path.backing))"
        case .software(let reason):
            "software fallback(\(reason))"
        case .unavailable(let reason):
            "unavailable(\(reason))"
        }
    }
}
