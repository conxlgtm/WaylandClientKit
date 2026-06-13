import Testing
import WaylandClient
import WaylandGraphicsPreview

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
        try defaultFrame.validateManagedPreviewSupport(
            configuration: configuration,
            capabilities: gpuCapableSurfaceCapabilities(),
            geometry: testGraphicsSurfaceGeometry()
        )
        #expect(
            try leaseState.prepareSubmission(leaseID: leaseID)
                == .show
        )
    }

    @Test
    func unsupportedMetadataIsRejectedBeforeLeaseIsConsumed() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()
        let frame = WaylandGraphicsSubmittedFrame.clearColor(
            WaylandGraphicsClearFrame(
                color: .black,
                metadata: WaylandGraphicsFrameMetadata(contentType: .game)
            )
        )

        #expect(
            throws: WaylandGraphicsError.unsupportedMetadata
        ) {
            try frame.validateManagedPreviewSupport(
                configuration: .default,
                capabilities: softwareOnlySurfaceCapabilities(),
                geometry: testGraphicsSurfaceGeometry()
            )
        }
        #expect(leaseState.activeLeaseID == leaseID)
    }

    @Test
    func metadataPolicyNoneRejectsHintsEvenWhenProtocolsAreAvailable() throws {
        let frame = WaylandGraphicsSubmittedFrame.clearColor(
            WaylandGraphicsClearFrame(
                color: .black,
                metadata: WaylandGraphicsFrameMetadata(
                    contentType: .game,
                    presentationHint: .vsync
                )
            )
        )

        #expect(throws: WaylandGraphicsError.unsupportedMetadata) {
            try frame.validateManagedPreviewSupport(
                configuration: .default,
                capabilities: gpuCapableSurfaceCapabilities(),
                geometry: testGraphicsSurfaceGeometry()
            )
        }
    }

    @Test
    func metadataPolicyPreferAvailableStillRequiresProtocols() throws {
        let metadata = WaylandGraphicsFrameMetadata(contentType: .game)

        #expect(
            throws: WaylandGraphicsError.unavailable(.metadataRequiredButUnavailable)
        ) {
            try metadata.validateManagedPreviewSupport(
                configuration: WaylandGraphicsConfiguration(
                    metadataPolicy: .preferAvailable
                ),
                capabilities: softwareOnlySurfaceCapabilities(),
                geometry: testGraphicsSurfaceGeometry()
            )
        }
    }

    @Test
    func safeMetadataIsAcceptedWhenPolicyAndProtocolsAreAvailable() throws {
        let frame = WaylandGraphicsSubmittedFrame.clearColor(
            WaylandGraphicsClearFrame(
                color: .black,
                metadata: WaylandGraphicsFrameMetadata(
                    contentType: .game,
                    presentationHint: .vsync
                )
            )
        )

        try frame.validateManagedPreviewSupport(
            configuration: WaylandGraphicsConfiguration(metadataPolicy: .preferAvailable),
            capabilities: gpuCapableSurfaceCapabilities(),
            geometry: testGraphicsSurfaceGeometry()
        )
    }

    @Test
    func partialDamageIsAcceptedWhenWithinSurfaceBounds() throws {
        let damage = WaylandGraphicsDamageRegion(
            rects: [try LogicalRect(x: 0, y: 0, width: 10, height: 10)]
        )
        let metadata = WaylandGraphicsFrameMetadata(damage: damage)

        try metadata.validateManagedPreviewSupport(
            configuration: .default,
            capabilities: gpuCapableSurfaceCapabilities(),
            geometry: testGraphicsSurfaceGeometry()
        )
    }

    @Test
    func noIntersectionGraphicsDamageIsInvalidDamageRegion() throws {
        let damage = WaylandGraphicsDamageRegion(
            rects: [try LogicalRect(x: 101, y: 0, width: 20, height: 10)]
        )
        let metadata = WaylandGraphicsFrameMetadata(damage: damage)

        #expect(throws: WaylandGraphicsError.invalidDamageRegion) {
            try metadata.validateManagedPreviewSupport(
                configuration: .default,
                capabilities: gpuCapableSurfaceCapabilities(),
                geometry: testGraphicsSurfaceGeometry()
            )
        }
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
    func requireExplicitValidatesWhenExplicitSyncExists() throws {
        let configuration = WaylandGraphicsConfiguration(
            synchronizationPolicy: .requireExplicit
        )

        try configuration.validateManagedPreviewSupport(
            capabilities: gpuCapableSurfaceCapabilities()
        )
    }

    @Test
    func preferPacingPoliciesValidateForRuntimeFallbackOrActivation() throws {
        let fifoConfiguration = WaylandGraphicsConfiguration(
            pacingPolicy: .preferFIFO
        )
        let commitTimingConfiguration = WaylandGraphicsConfiguration(
            pacingPolicy: .preferCommitTiming
        )

        try fifoConfiguration.validateManagedPreviewSupport(
            capabilities: gpuCapableSurfaceCapabilities()
        )
        try commitTimingConfiguration.validateManagedPreviewSupport(
            capabilities: gpuCapableSurfaceCapabilities()
        )
    }

    @Test
    func publicPoliciesMapToManagedGPUActivationPolicies() {
        let explicitConfiguration = WaylandGraphicsConfiguration(
            synchronizationPolicy: .preferExplicit
        )
        let requiredExplicitConfiguration = WaylandGraphicsConfiguration(
            synchronizationPolicy: .requireExplicit
        )
        let fifoConfiguration = WaylandGraphicsConfiguration(
            pacingPolicy: .preferFIFO
        )
        let commitTimingConfiguration = WaylandGraphicsConfiguration(
            pacingPolicy: .preferCommitTiming
        )

        #expect(
            explicitConfiguration.gpuSynchronizationPolicy
                == .preferExplicitFallbackToImplicit
        )
        #expect(requiredExplicitConfiguration.gpuSynchronizationPolicy == .requireExplicit)
        #expect(fifoConfiguration.gpuPacingPolicy == .preferFIFO)
        #expect(commitTimingConfiguration.gpuPacingPolicy == .preferCommitTiming)
    }

    @Test
    func requirePresentationFeedbackFailsWhenUnavailable() {
        let configuration = WaylandGraphicsConfiguration(
            presentationFeedbackPolicy: .require
        )

        #expect(
            throws: WaylandGraphicsError.unavailable(
                .presentationFeedbackUnavailable
            )
        ) {
            try configuration.validateManagedPreviewSupport(
                capabilities: softwareOnlySurfaceCapabilities()
            )
        }
    }

    @Test
    func requestWhenAvailableSkipsFeedbackWhenUnavailable() {
        let configuration = WaylandGraphicsConfiguration(
            presentationFeedbackPolicy: .requestWhenAvailable
        )

        #expect(
            !WaylandGraphicsWindowBackingStorage.shouldRequestPresentationFeedback(
                configuration: configuration,
                capabilities: softwareOnlySurfaceCapabilities()
            )
        )
    }

    @Test
    func requestWhenAvailableRequestsFeedbackWhenAvailable() {
        let configuration = WaylandGraphicsConfiguration(
            presentationFeedbackPolicy: .requestWhenAvailable
        )

        #expect(
            WaylandGraphicsWindowBackingStorage.shouldRequestPresentationFeedback(
                configuration: configuration,
                capabilities: gpuCapableSurfaceCapabilities()
            )
        )
    }

    @Test
    func managedPreviewDoesNotReportGbmActiveWithoutGbmProbe() throws {
        let path = try WaylandDisplay.managedPreviewRuntimePath(
            capabilities: gpuCapableSurfaceCapabilities(),
            configuration: .default
        )

        #expect(path.backing == .advertised)
        #expect(path.dmabuf == .advertised)
        #expect(path.surfaceFeedback == .advertised)
        #expect(path.renderNode == .unavailable)
        #expect(path.gbm == .unavailable)
        #expect(path.egl == .unavailable)
        #expect(path.dmabufImport == .unavailable)
        #expect(path.bufferLifecycle == .unavailable)
    }

    @Test
    func requireGPUProjectsAdvertisedPathBeforeSubmission() throws {
        let path = try WaylandDisplay.managedPreviewRuntimePath(
            capabilities: gpuCapableSurfaceCapabilities(),
            configuration: WaylandGraphicsConfiguration(fallbackPolicy: .requireGPU)
        )

        #expect(path.backing == .advertised)
        #expect(path.dmabuf == .advertised)
    }
}
