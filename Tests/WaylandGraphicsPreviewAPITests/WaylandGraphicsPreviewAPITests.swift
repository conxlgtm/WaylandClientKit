import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsPreviewAPITests {
    @Test
    func publicCapabilitiesProjectStableClientFacts() {
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
            linuxDmabuf: .available(version: 4)
        )

        let capabilities = WaylandGraphicsSurfaceCapabilities(
            capabilities: clientCapabilities
        )

        #expect(capabilities.dmabuf == .available(version: 4))
        #expect(capabilities.presentationFeedback == .available(version: 1))
        #expect(capabilities.explicitSync == .unavailable)
        #expect(capabilities.framePacing == .unavailable)
        #expect(capabilities.colorMetadata == .unavailable)
    }

    @Test
    func fallbackPolicyDistinguishesSoftwareFallbackAndRequiredGPUFailure() {
        let capabilities = WaylandGraphicsSurfaceCapabilities(
            dmabuf: .unavailable,
            explicitSync: .unavailable,
            framePacing: .unavailable,
            colorMetadata: .unavailable,
            presentationFeedback: .unavailable
        )

        #expect(
            WaylandGraphicsFallbackPolicy.preferGPUFallbackToSoftware.decide(
                capabilities: capabilities
            ) == .software(.dmabufUnavailable)
        )
        #expect(
            WaylandGraphicsFallbackPolicy.requireGPU.decide(
                capabilities: capabilities
            ) == .unavailable(.dmabufUnavailable)
        )
        #expect(
            WaylandGraphicsFallbackPolicy.forceSoftware.decide(
                capabilities: capabilities
            ) == .software(.forcedSoftware)
        )
    }

    @Test
    func projectedRuntimePathReportsAdvertisedGPUFacts() {
        let capabilities = WaylandGraphicsSurfaceCapabilities(
            dmabuf: .available(version: 4),
            explicitSync: .available(version: 1),
            framePacing: WaylandGraphicsFramePacingAvailability(
                fifo: .available(version: 1),
                commitTiming: .unavailable
            ),
            colorMetadata: WaylandGraphicsColorMetadataAvailability(
                contentType: .available(version: 1),
                alphaModifier: .unavailable,
                tearingControl: .available(version: 1),
                colorRepresentation: .unavailable,
                colorManagement: .unavailable
            ),
            presentationFeedback: .available(version: 1)
        )

        let path = WaylandGraphicsRuntimePath.projected(capabilities: capabilities)

        #expect(path.backing == .advertised)
        #expect(path.dmabuf == .advertised)
        #expect(path.gbm == .unavailable)
        #expect(path.egl == .unavailable)
        #expect(path.explicitSync == .advertised)
        #expect(path.pacing.fifo == .advertised)
        #expect(path.pacing.commitTiming == .unavailable)
        #expect(path.metadata.contentType == .advertised)
        #expect(path.metadata.alphaModifier == .unavailable)
        #expect(path.metadata.tearingControl == .advertised)
        #expect(path.presentationFeedback == .advertised)
        #expect(path.fallback == nil)
    }

    @Test
    func projectedRuntimePathPreservesPendingMetadataSupport() {
        let capabilities = WaylandGraphicsSurfaceCapabilities(
            dmabuf: .available(version: 4),
            explicitSync: .unavailable,
            framePacing: .unavailable,
            colorMetadata: WaylandGraphicsColorMetadataAvailability(
                contentType: .available(version: 1),
                alphaModifier: .unavailable,
                tearingControl: .unavailable,
                colorRepresentation: .pending(version: 1),
                colorManagement: .available(version: 2)
            ),
            presentationFeedback: .unavailable
        )

        let path = WaylandGraphicsRuntimePath.projected(capabilities: capabilities)

        #expect(capabilities.colorMetadata.colorRepresentation.isAvailable == false)
        #expect(capabilities.colorMetadata.colorRepresentation.version == 1)
        #expect(path.metadata.contentType == .advertised)
        #expect(path.metadata.colorRepresentation == .pending)
        #expect(path.metadata.colorManagement == .advertised)
    }

    @Test
    func projectedRuntimePathConstructsFallbackFromSingleBackingDecision() {
        let capabilities = WaylandGraphicsSurfaceCapabilities(
            dmabuf: .unavailable,
            explicitSync: .unavailable,
            framePacing: .unavailable,
            colorMetadata: .unavailable,
            presentationFeedback: .unavailable
        )

        let path = WaylandGraphicsRuntimePath.projected(
            capabilities: capabilities,
            policy: .preferGPUFallbackToSoftware
        )

        #expect(path.backing == .fallback(.dmabufUnavailable))
        #expect(path.dmabuf == .fallback(.dmabufUnavailable))
        #expect(path.fallback == .dmabufUnavailable)
    }

    @Test
    func forceSoftwareProjectedRuntimePathReportsSoftwareFallback() {
        let path = WaylandGraphicsRuntimePath.projected(
            capabilities: gpuCapableSurfaceCapabilities(),
            policy: .forceSoftware
        )

        #expect(path.backing == .fallback(.forcedSoftware))
        #expect(path.dmabuf == .fallback(.forcedSoftware))
        #expect(path.fallback == .forcedSoftware)
    }

    @Test
    func forceSoftwareDecisionAndProjectedPathAgree() {
        let capabilities = gpuCapableSurfaceCapabilities()
        let decision = WaylandGraphicsFallbackPolicy.forceSoftware.decide(
            capabilities: capabilities
        )
        let path = WaylandGraphicsRuntimePath.projected(
            capabilities: capabilities,
            policy: .forceSoftware
        )

        #expect(decision == .software(.forcedSoftware))
        #expect(path.backing == .fallback(.forcedSoftware))
        #expect(path.fallback == .forcedSoftware)
    }

    @Test
    func managedPreviewFallbackPathPreservesAdvertisedDmabufFact() {
        let capabilities = gpuCapableSurfaceCapabilities()
        let path = WaylandGraphicsRuntimePath.softwareFallback(
            capabilities: capabilities,
            reason: .gbmUnavailable
        )

        #expect(path.backing == .fallback(.gbmUnavailable))
        #expect(path.dmabuf == .advertised)
        #expect(path.gbm == .fallback(.gbmUnavailable))
        #expect(path.egl == .fallback(.gbmUnavailable))
    }

    @Test
    func managedPreviewConfigurationDefaultsAreConservative() {
        let configuration = WaylandGraphicsConfiguration.default

        #expect(configuration.fallbackPolicy == .preferGPUFallbackToSoftware)
        #expect(configuration.synchronizationPolicy == .implicitOnly)
        #expect(configuration.pacingPolicy == .none)
        #expect(configuration.metadataPolicy == .none)
    }

    @Test
    func clearFrameCarriesColorAndOptionalMetadata() {
        let color = WaylandGraphicsXRGBColor(red: 0x10, green: 0x20, blue: 0x30)
        let metadata = WaylandGraphicsFrameMetadata(
            contentType: .game,
            presentationHint: .vsync
        )
        let clearFrame = WaylandGraphicsClearFrame(color: color, metadata: metadata)
        let expectedSubmittedFrame = WaylandGraphicsSubmittedFrame.clearColor(
            WaylandGraphicsClearFrame(color: color)
        )

        #expect(color.red == 0x10)
        #expect(color.green == 0x20)
        #expect(color.blue == 0x30)
        #expect(clearFrame.metadata.contentType == .game)
        #expect(clearFrame.metadata.presentationHint == .vsync)
        #expect(WaylandGraphicsSubmittedFrame.clearColor(color) == expectedSubmittedFrame)
    }
}

private func gpuCapableSurfaceCapabilities() -> WaylandGraphicsSurfaceCapabilities {
    WaylandGraphicsSurfaceCapabilities(
        dmabuf: .available(version: 4),
        explicitSync: .available(version: 1),
        framePacing: WaylandGraphicsFramePacingAvailability(
            fifo: .available(version: 1),
            commitTiming: .available(version: 1)
        ),
        colorMetadata: WaylandGraphicsColorMetadataAvailability(
            contentType: .available(version: 1),
            alphaModifier: .available(version: 1),
            tearingControl: .available(version: 1),
            colorRepresentation: .available(version: 1),
            colorManagement: .available(version: 1)
        ),
        presentationFeedback: .available(version: 1)
    )
}
