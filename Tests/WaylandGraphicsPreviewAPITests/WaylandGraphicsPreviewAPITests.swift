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
            reason: .managedGPUSubmissionUnavailable
        )

        #expect(path.backing == .fallback(.managedGPUSubmissionUnavailable))
        #expect(path.dmabuf == .advertised)
        #expect(path.gbm == .fallback(.managedGPUSubmissionUnavailable))
        #expect(path.egl == .fallback(.managedGPUSubmissionUnavailable))
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

@Suite
struct WaylandGraphicsPreviewManagedSubmissionTests {
    @Test
    func preferAvailableMetadataDoesNotRejectDefaultFrame() throws {
        let configuration = WaylandGraphicsConfiguration(
            metadataPolicy: .preferAvailable
        )
        let defaultFrame = WaylandGraphicsSubmittedFrame.clearColor(.black)
        var leaseState = WaylandGraphicsFrameLeaseState()

        try configuration.validateManagedPreviewSupport(
            capabilities: gpuCapableSurfaceCapabilities()
        )
        let leaseID = try leaseState.issueLease()
        #expect(
            try leaseState.prepareSubmission(leaseID: leaseID, frame: defaultFrame)
                == .show
        )
    }

    @Test
    func nonDefaultMetadataIsRejectedBeforeLeaseIsConsumed() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()
        let frame = WaylandGraphicsSubmittedFrame.clearColor(
            WaylandGraphicsClearFrame(
                color: .black,
                metadata: WaylandGraphicsFrameMetadata(contentType: .game)
            )
        )

        #expect(throws: WaylandGraphicsError.unsupportedMetadata) {
            try leaseState.prepareSubmission(leaseID: leaseID, frame: frame)
        }
        #expect(leaseState.activeLeaseID == leaseID)
    }

    @Test
    func requireExplicitFailsWhenExplicitSyncUnavailable() {
        let configuration = WaylandGraphicsConfiguration(
            synchronizationPolicy: .requireExplicit
        )

        #expect(
            throws: WaylandGraphicsError.unavailable(
                .explicitSyncRequiredButUnavailable
            )
        ) {
            try configuration.validateManagedPreviewSupport(
                capabilities: softwareOnlySurfaceCapabilities()
            )
        }
    }

    @Test
    func requireExplicitFailsWithManagedGpuUnavailableWhenExplicitSyncExists() {
        let configuration = WaylandGraphicsConfiguration(
            synchronizationPolicy: .requireExplicit
        )

        #expect(
            throws: WaylandGraphicsError.unavailable(
                .managedGPUSubmissionUnavailable
            )
        ) {
            try configuration.validateManagedPreviewSupport(
                capabilities: gpuCapableSurfaceCapabilities()
            )
        }
    }

    @Test
    func pacingPolicyIsRejectedUntilManagedPacingExists() {
        let fifoConfiguration = WaylandGraphicsConfiguration(
            pacingPolicy: .preferFIFO
        )
        let commitTimingConfiguration = WaylandGraphicsConfiguration(
            pacingPolicy: .preferCommitTiming
        )

        #expect(throws: WaylandGraphicsError.unsupportedPacing) {
            try fifoConfiguration.validateManagedPreviewSupport(
                capabilities: gpuCapableSurfaceCapabilities()
            )
        }
        #expect(throws: WaylandGraphicsError.unsupportedPacing) {
            try commitTimingConfiguration.validateManagedPreviewSupport(
                capabilities: gpuCapableSurfaceCapabilities()
            )
        }
    }

    @Test
    func managedPreviewDoesNotReportGbmUnavailableWithoutGbmProbe() throws {
        let path = try WaylandDisplay.managedPreviewRuntimePath(
            capabilities: gpuCapableSurfaceCapabilities(),
            configuration: .default
        )

        #expect(path.backing == .fallback(.managedGPUSubmissionUnavailable))
        #expect(path.dmabuf == .advertised)
        #expect(path.gbm == .fallback(.managedGPUSubmissionUnavailable))
        #expect(path.egl == .fallback(.managedGPUSubmissionUnavailable))
    }

    @Test
    func requireGPUFailsWithManagedGpuSubmissionUnavailableWhenGpuPathIsNotPublic() {
        #expect(
            throws: WaylandGraphicsError.unavailable(
                .managedGPUSubmissionUnavailable
            )
        ) {
            _ = try WaylandDisplay.managedPreviewRuntimePath(
                capabilities: gpuCapableSurfaceCapabilities(),
                configuration: WaylandGraphicsConfiguration(fallbackPolicy: .requireGPU)
            )
        }
    }

    @Test
    func nextFrameRejectsSecondActiveLease() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()

        let leaseID = try leaseState.issueLease()

        #expect(leaseID == 1)
        #expect(throws: WaylandGraphicsError.frameLeaseActive) {
            try leaseState.issueLease()
        }
    }

    @Test
    func cancelAllowsNextFrame() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()

        let leaseID = try leaseState.issueLease()
        leaseState.cancel(leaseID: leaseID)

        #expect(try leaseState.issueLease() == 2)
    }

    @Test
    func doubleSubmitConsumesLeaseOnce() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()
        let frame = WaylandGraphicsSubmittedFrame.clearColor(.black)

        #expect(
            try leaseState.prepareSubmission(leaseID: leaseID, frame: frame) == .show
        )
        #expect(throws: WaylandGraphicsError.frameLeaseConsumed) {
            try leaseState.prepareSubmission(leaseID: leaseID, frame: frame)
        }
    }

    @Test
    func consumedLeaseReportsConsumedBeforeMetadataValidation() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()
        _ = try leaseState.prepareSubmission(leaseID: leaseID, frame: .clearColor(.black))
        let unsupportedFrame = WaylandGraphicsSubmittedFrame.clearColor(
            WaylandGraphicsClearFrame(
                color: .black,
                metadata: WaylandGraphicsFrameMetadata(contentType: .game)
            )
        )

        #expect(throws: WaylandGraphicsError.frameLeaseConsumed) {
            try leaseState.prepareSubmission(leaseID: leaseID, frame: unsupportedFrame)
        }
    }

    @Test
    func wrongLeaseReportsConsumedBeforeMetadataValidation() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        _ = try leaseState.issueLease()
        let unsupportedFrame = WaylandGraphicsSubmittedFrame.clearColor(
            WaylandGraphicsClearFrame(
                color: .black,
                metadata: WaylandGraphicsFrameMetadata(contentType: .game)
            )
        )

        #expect(throws: WaylandGraphicsError.frameLeaseConsumed) {
            try leaseState.prepareSubmission(leaseID: 999, frame: unsupportedFrame)
        }
    }

    @Test
    func submissionInFlightRejectsNewLease() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()

        _ = try leaseState.prepareSubmission(
            leaseID: leaseID,
            frame: .clearColor(.black)
        )

        #expect(throws: WaylandGraphicsError.frameLeaseActive) {
            try leaseState.issueLease()
        }
    }

    @Test
    func submitAfterCloseFailsWithoutDrawing() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()

        leaseState.close()

        #expect(throws: WaylandGraphicsError.backingClosed) {
            try leaseState.prepareSubmission(
                leaseID: leaseID,
                frame: .clearColor(.black)
            )
        }
    }

    @Test
    func secondSubmittedFrameUsesRedrawNotShow() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let frame = WaylandGraphicsSubmittedFrame.clearColor(.black)

        let firstLeaseID = try leaseState.issueLease()
        #expect(
            try leaseState.prepareSubmission(leaseID: firstLeaseID, frame: frame)
                == .show
        )
        try leaseState.finishSubmission()

        let secondLeaseID = try leaseState.issueLease()
        #expect(
            try leaseState.prepareSubmission(leaseID: secondLeaseID, frame: frame)
                == .redraw
        )
    }

    @Test
    func closedWindowDisplayFailuresMapToTypedPreviewError() {
        let windowID = WindowID(rawValue: 42)

        #expect(
            WaylandGraphicsErrorMapper.mapWindowLifecycleError(
                ClientError.display(.unknownWindow(windowID)),
                windowID: windowID
            ) == .windowClosed
        )
        #expect(
            WaylandGraphicsErrorMapper.mapWindowLifecycleError(
                ClientError.window(
                    windowID,
                    .invalidLifecycleTransition(.presentAfterDestroyed)
                ),
                windowID: windowID
            ) == .windowClosed
        )
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

private func softwareOnlySurfaceCapabilities() -> WaylandGraphicsSurfaceCapabilities {
    WaylandGraphicsSurfaceCapabilities(
        dmabuf: .unavailable,
        explicitSync: .unavailable,
        framePacing: .unavailable,
        colorMetadata: .unavailable,
        presentationFeedback: .unavailable
    )
}
