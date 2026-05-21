import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsPreviewClientTests {
    @Test
    func graphicsPreviewTypesCompileForExternalClients() throws {
        let clientCapabilities = WaylandCapabilities(
            clipboard: .unavailable,
            dragAndDrop: .unavailable,
            dragActionNegotiation: .unavailable,
            primarySelection: .unavailable,
            xdgDecoration: .unavailable,
            xdgOutput: .unavailable,
            viewporter: .unavailable,
            presentationTime: .available(version: 1),
            fractionalScale: .unavailable,
            cursorShape: .unavailable,
            textInput: .unavailable,
            linuxDmabuf: .unavailable
        )

        let capabilities = WaylandGraphicsSurfaceCapabilities(
            capabilities: clientCapabilities
        )
        let path = WaylandGraphicsRuntimePath.projected(
            capabilities: capabilities,
            policy: .preferGPUFallbackToSoftware
        )
        let decision = WaylandGraphicsFallbackPolicy.requireGPU.decide(
            capabilities: capabilities
        )

        #expect(path.backing == .fallback(.dmabufUnavailable))
        #expect(decision == .unavailable(.dmabufUnavailable))
    }

    @Test
    func displayGraphicsPreviewMethodsAreAvailableToExternalClients() async throws {
        func acceptsDisplay(_ display: WaylandDisplay) async throws {
            _ = try await display.graphicsSurfaceCapabilities()
            _ = try await display.graphicsRuntimePath(policy: .forceSoftware)
            _ = try await display.graphicsBackingDecision(policy: .requireGPU)
            let backing = try await display.createGraphicsWindowBacking(
                windowConfiguration: WindowConfiguration(
                    title: "Graphics Preview Client",
                    appID: "graphics-preview-client",
                    initialWidth: 16,
                    initialHeight: 16
                ),
                graphicsConfiguration: WaylandGraphicsConfiguration(
                    fallbackPolicy: .forceSoftware
                )
            )
            _ = backing.window
            _ = try await backing.runtimePath
            let lease = try await backing.nextFrame()
            try await lease.submit(
                .clearColor(WaylandGraphicsXRGBColor(red: 0, green: 0, blue: 0))
            )
            try await backing.close()
        }

        _ = acceptsDisplay
    }

    @Test
    func managedPreviewSubmissionTypesCompileForExternalClients() {
        let configuration = WaylandGraphicsConfiguration(
            fallbackPolicy: .preferGPUFallbackToSoftware,
            synchronizationPolicy: .preferExplicit,
            pacingPolicy: .preferFIFO,
            metadataPolicy: .preferAvailable
        )
        let metadata = WaylandGraphicsFrameMetadata(
            contentType: .video,
            presentationHint: .async
        )
        let frame = WaylandGraphicsSubmittedFrame.clearColor(
            WaylandGraphicsXRGBColor(red: 1, green: 2, blue: 3)
        )

        #expect(configuration.synchronizationPolicy == .preferExplicit)
        #expect(metadata.contentType == .video)
        #expect(frame == .clearColor(WaylandGraphicsClearFrame(
            color: WaylandGraphicsXRGBColor(red: 1, green: 2, blue: 3)
        )))
    }
}
