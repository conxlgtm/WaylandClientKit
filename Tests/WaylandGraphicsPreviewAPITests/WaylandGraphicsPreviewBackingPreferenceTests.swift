import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsPreviewBackingPreferenceTests {
    @Test
    func defaultConfigurationRequestsManagedGPUWithSoftwareFallback() {
        #expect(WaylandGraphicsConfiguration.default.presentationMode == .managedGPU)
        #expect(WaylandGraphicsConfiguration.default.backingPreference == .managedGPU)
        #expect(
            WaylandGraphicsConfiguration.default.fallbackPolicy
                == .preferGPUFallbackToSoftware
        )
    }

    @Test
    func externalGPUPresentationModeProjectsAdvertisedPath() throws {
        let configuration = WaylandGraphicsConfiguration(
            presentationMode: .externalGPU,
            fallbackPolicy: .requireGPU
        )
        let path = try WaylandDisplay.managedPreviewRuntimePath(
            capabilities: gpuCapableSurfaceCapabilities(),
            configuration: configuration
        )

        #expect(configuration.presentationMode == .externalGPU)
        #expect(configuration.backingPreference == .managedGPU)
        #expect(path.backing == .advertised)
        #expect(path.dmabuf == .advertised)
    }

    @Test
    func softwareBackingPreferenceForcesSoftwarePath() throws {
        let path = try WaylandDisplay.managedPreviewRuntimePath(
            capabilities: gpuCapableSurfaceCapabilities(),
            configuration: WaylandGraphicsConfiguration(
                fallbackPolicy: .requireGPU,
                backingPreference: .software
            )
        )

        #expect(path.backing == .fallback(.forcedSoftware))
        #expect(path.gbm == .fallback(.forcedSoftware))
        #expect(path.egl == .fallback(.forcedSoftware))
    }

    @Test
    func requireExplicitRejectsSoftwareBackingPreference() {
        #expect(
            throws: WaylandGraphicsError.unavailable(
                .managedGPUSubmissionUnavailable
            )
        ) {
            _ = try WaylandDisplay.managedPreviewRuntimePath(
                capabilities: gpuCapableSurfaceCapabilities(),
                configuration: WaylandGraphicsConfiguration(
                    backingPreference: .software,
                    synchronizationPolicy: .requireExplicit
                )
            )
        }
    }

    @Test
    func requireExplicitRejectsForcedSoftwareFallback() {
        #expect(
            throws: WaylandGraphicsError.unavailable(
                .managedGPUSubmissionUnavailable
            )
        ) {
            _ = try WaylandDisplay.managedPreviewRuntimePath(
                capabilities: gpuCapableSurfaceCapabilities(),
                configuration: WaylandGraphicsConfiguration(
                    fallbackPolicy: .forceSoftware,
                    synchronizationPolicy: .requireExplicit
                )
            )
        }
    }

    @Test
    func managedGPUPreferenceProjectsAdvertisedPathBeforeSetup() throws {
        let path = try WaylandDisplay.managedPreviewRuntimePath(
            capabilities: gpuCapableSurfaceCapabilities(),
            configuration: WaylandGraphicsConfiguration(
                fallbackPolicy: .preferGPUFallbackToSoftware,
                backingPreference: .managedGPU
            )
        )

        #expect(path.backing == .advertised)
        #expect(path.dmabuf == .advertised)
        #expect(path.gbm == .unavailable)
        #expect(path.egl == .unavailable)
    }

    @Test
    func managedGPUPreferenceCanRequireGPUAtSubmissionTime() throws {
        let path = try WaylandDisplay.managedPreviewRuntimePath(
            capabilities: gpuCapableSurfaceCapabilities(),
            configuration: WaylandGraphicsConfiguration(
                fallbackPolicy: .requireGPU,
                backingPreference: .managedGPU
            )
        )

        #expect(path.backing == .advertised)
        #expect(path.dmabuf == .advertised)
    }

    @Test
    func frameResultReportsSubmissionFacts() throws {
        let metadata = WaylandGraphicsFrameMetadata(
            contentType: .game,
            presentationHint: .vsync
        )
        let runtimePath = WaylandGraphicsRuntimePath.softwareFallback(
            capabilities: gpuCapableSurfaceCapabilities(),
            reason: .managedGPUSubmissionUnavailable
        )
        let result = WaylandGraphicsFrameResult(
            runtimePath: runtimePath,
            operation: .redraw,
            size: try PositivePixelSize(width: 64, height: 32),
            metadata: metadata,
            presentationFeedbackRequested: true,
            synchronizationPolicy: .preferExplicit,
            pacingPolicy: .none
        )

        #expect(result.backing == .fallback(.managedGPUSubmissionUnavailable))
        #expect(result.metadata == metadata)
        #expect(result.presentationFeedbackRequested)
        #expect(result.synchronizationPolicy == .preferExplicit)
        #expect(result.pacingPolicy == .none)
    }
}
