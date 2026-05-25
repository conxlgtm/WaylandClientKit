import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsPreviewBackingPreferenceTests {
    @Test
    func defaultConfigurationRequestsManagedGPUWithSoftwareFallback() {
        #expect(WaylandGraphicsConfiguration.default.backingPreference == .managedGPU)
        #expect(
            WaylandGraphicsConfiguration.default.fallbackPolicy
                == .preferGPUFallbackToSoftware
        )
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
    func managedGPUPreferenceFallsBackWhenPublicGPUSubmissionIsUnavailable() throws {
        let path = try WaylandDisplay.managedPreviewRuntimePath(
            capabilities: gpuCapableSurfaceCapabilities(),
            configuration: WaylandGraphicsConfiguration(
                fallbackPolicy: .preferGPUFallbackToSoftware,
                backingPreference: .managedGPU
            )
        )

        #expect(path.backing == .fallback(.managedGPUSubmissionUnavailable))
        #expect(path.dmabuf == .advertised)
        #expect(path.gbm == .fallback(.managedGPUSubmissionUnavailable))
        #expect(path.egl == .fallback(.managedGPUSubmissionUnavailable))
    }

    @Test
    func managedGPUPreferenceCanRequireGPU() {
        #expect(
            throws: WaylandGraphicsError.unavailable(
                .managedGPUSubmissionUnavailable
            )
        ) {
            _ = try WaylandDisplay.managedPreviewRuntimePath(
                capabilities: gpuCapableSurfaceCapabilities(),
                configuration: WaylandGraphicsConfiguration(
                    fallbackPolicy: .requireGPU,
                    backingPreference: .managedGPU
                )
            )
        }
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
