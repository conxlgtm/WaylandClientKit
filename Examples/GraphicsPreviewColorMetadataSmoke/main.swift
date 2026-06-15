import Foundation
import WaylandClient
import WaylandExampleSupport
import WaylandGraphicsPreview

@main
enum GraphicsPreviewColorMetadataSmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())
        let synchronization = try requestedSynchronizationPolicy(options.synchronization)
        let pacing = try requestedPacingRequest(options.pacing)
        let metadata = try requestedMetadata(options)

        try await WaylandDisplay.withConnection { display in
            let backing = try await display.createGraphicsWindowBacking(
                windowConfiguration: WindowConfiguration(
                    title: "WaylandClientKit Color Metadata Smoke",
                    appID: "wayland-client-kit-color-metadata-smoke",
                    initialWidth: 192,
                    initialHeight: 128,
                    bufferCount: 2
                ),
                graphicsConfiguration: WaylandGraphicsConfiguration(
                    metadataPolicy: .preferAvailable
                )
            )
            let lease = try await backing.nextFrame()
            let schedule = WaylandGraphicsFrameSchedule(
                synchronization: synchronization,
                pacing: pacing,
                presentationFeedback: .requestWhenAvailable
            )
            let result = try await lease.submit(
                .clearColor(
                    WaylandGraphicsClearFrame(
                        color: WaylandGraphicsXRGBColor(red: 0x30, green: 0xB0, blue: 0x70),
                        metadata: metadata
                    )
                ),
                schedule: schedule
            )

            log("feature: graphics-preview-color-metadata")
            log("operation: clear-frame \(result.operation)")
            log("sync requested: \(syncDescription(schedule.synchronization))")
            log("explicit sync actual: \(status(result.runtimePath.explicitSync))")
            log("pacing requested: \(pacingDescription(schedule.pacing))")
            log("FIFO actual: \(status(result.runtimePath.pacing.fifo))")
            log("commit timing actual: \(status(result.runtimePath.pacing.commitTiming))")
            log("content type requested: \(contentTypeDescription(metadata.contentType))")
            log("content type actual: \(status(result.runtimePath.metadata.contentType))")
            log(
                "presentation hint requested: \(presentationHintDescription(metadata.presentationHint))"
            )
            log("tearing control actual: \(status(result.runtimePath.metadata.tearingControl))")
            log("alpha requested: \(metadata.alpha.map { String($0.rawValue) } ?? "not requested")")
            log("alpha actual: \(status(result.runtimePath.metadata.alphaModifier))")
            log(
                "color representation requested: \(metadata.colorRepresentation == nil ? "not requested" : "requested")"
            )
            log(
                "color representation actual: \(status(result.runtimePath.metadata.colorRepresentation))"
            )
            log("color management actual: \(status(result.runtimePath.metadata.colorManagement))")
            log("fallback: \(result.runtimePath.fallback.map(String.init(describing:)) ?? "none")")
            log("failure: none")
            log("cleanup: pass")
            try await backing.close()
        }
    }

    private static func requestedMetadata(
        _ options: ExampleRunOptions
    ) throws -> WaylandGraphicsFrameMetadata {
        WaylandGraphicsFrameMetadata(
            contentType: try requestedContentType(options.contentType),
            presentationHint: try requestedPresentationHint(options.presentationHint),
            alpha: .opaque,
            colorRepresentation: WaylandGraphicsColorRepresentation(
                alphaMode: .premultipliedElectrical
            )
        )
    }

    private static func requestedSynchronizationPolicy(
        _ rawValue: String?
    ) throws -> WaylandGraphicsSynchronizationPolicy {
        switch normalized(rawValue) {
        case nil, "implicit", "implicit-only":
            .implicitOnly
        case "prefer-explicit", "explicit":
            .preferExplicit
        case "require-explicit":
            .requireExplicit
        case .some(let value):
            throw ExampleRunOptionError.unknownArgument("--sync \(value)")
        }
    }

    private static func requestedPacingRequest(
        _ rawValue: String?
    ) throws -> WaylandGraphicsFramePacingRequest {
        switch normalized(rawValue) {
        case nil, "none":
            .none
        case "fifo":
            .fifo
        case "commit-timing":
            .commitTiming
        case .some(let value):
            throw ExampleRunOptionError.unknownArgument("--pacing \(value)")
        }
    }

    private static func requestedContentType(
        _ rawValue: String?
    ) throws -> WaylandGraphicsContentType? {
        switch normalized(rawValue) {
        case nil, "none":
            nil
        case "photo":
            .photo
        case "video":
            .video
        case "game":
            .game
        case .some(let value):
            throw ExampleRunOptionError.unknownArgument("--content-type \(value)")
        }
    }

    private static func requestedPresentationHint(
        _ rawValue: String?
    ) throws -> WaylandGraphicsPresentationHint? {
        switch normalized(rawValue) {
        case nil, "none":
            nil
        case "vsync":
            .vsync
        case "async":
            .async
        case .some(let value):
            throw ExampleRunOptionError.unknownArgument("--presentation-hint \(value)")
        }
    }

    nonisolated private static func normalized(_ value: String?) -> String? {
        value?.lowercased().replacingOccurrences(of: "_", with: "-")
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

    nonisolated private static func syncDescription(
        _ policy: WaylandGraphicsSynchronizationPolicy
    ) -> String {
        switch policy {
        case .implicitOnly:
            "implicitOnly"
        case .preferExplicit:
            "preferExplicit"
        case .requireExplicit:
            "requireExplicit"
        }
    }

    nonisolated private static func pacingDescription(
        _ request: WaylandGraphicsFramePacingRequest
    ) -> String {
        switch request {
        case .none:
            "none"
        case .fifo:
            "fifo"
        case .commitTiming:
            "commitTiming"
        }
    }

    nonisolated private static func contentTypeDescription(
        _ contentType: WaylandGraphicsContentType?
    ) -> String {
        switch contentType {
        case nil:
            "not requested"
        case .some(.none):
            "none"
        case .some(.photo):
            "photo"
        case .some(.video):
            "video"
        case .some(.game):
            "game"
        }
    }

    nonisolated private static func presentationHintDescription(
        _ presentationHint: WaylandGraphicsPresentationHint?
    ) -> String {
        switch presentationHint {
        case nil:
            "not requested"
        case .vsync:
            "vsync"
        case .async:
            "async"
        }
    }

    nonisolated private static func log(_ message: String) {
        print(message)
    }
}
