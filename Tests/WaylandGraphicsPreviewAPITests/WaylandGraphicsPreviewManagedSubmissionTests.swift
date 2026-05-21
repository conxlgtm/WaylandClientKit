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
            throws: WaylandGraphicsError.unavailable(.metadataRequiredButUnavailable)
        ) {
            try frame.validateManagedPreviewSupport(
                capabilities: softwareOnlySurfaceCapabilities(),
                geometry: testGraphicsSurfaceGeometry()
            )
        }
        #expect(leaseState.activeLeaseID == leaseID)
    }

    @Test
    func safeMetadataIsAcceptedWhenProtocolsAreAvailable() throws {
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
            capabilities: gpuCapableSurfaceCapabilities(),
            geometry: testGraphicsSurfaceGeometry()
        )
    }

    @Test
    func partialDamageIsValidatedThenReportedUnsupported() throws {
        let damage = WaylandGraphicsDamageRegion(
            rects: [try LogicalRect(x: 0, y: 0, width: 10, height: 10)]
        )
        let metadata = WaylandGraphicsFrameMetadata(damage: damage)

        #expect(throws: WaylandGraphicsError.unsupportedDamage) {
            try metadata.validateManagedPreviewSupport(
                capabilities: gpuCapableSurfaceCapabilities(),
                geometry: testGraphicsSurfaceGeometry()
            )
        }
    }

    @Test
    func outOfBoundsDamageIsRejectedBeforeUnsupportedPartialDamage() throws {
        let damage = WaylandGraphicsDamageRegion(
            rects: [try LogicalRect(x: 90, y: 0, width: 20, height: 10)]
        )
        let metadata = WaylandGraphicsFrameMetadata(damage: damage)

        #expect(throws: WaylandGraphicsError.invalidDamageRegion) {
            try metadata.validateManagedPreviewSupport(
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
}
