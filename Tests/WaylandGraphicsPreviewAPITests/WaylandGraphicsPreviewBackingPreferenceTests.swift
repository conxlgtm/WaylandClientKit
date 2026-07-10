import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsPresentationPolicyTests {
    @Test
    func defaultConfigurationRequestsManagedGPUWithSoftwareFallback() {
        #expect(
            WaylandGraphicsConfiguration.default.presentationPolicy
                == .managedGPU(fallback: .software)
        )
    }

    @Test
    func everyPolicyMapsToOneRuntimePathOutcome() throws {
        for testCase in policyRuntimePathCases {
            do {
                let path = try WaylandDisplay.managedPreviewRuntimePath(
                    capabilities: testCase.capabilities,
                    configuration: WaylandGraphicsConfiguration(
                        presentationPolicy: testCase.policy
                    )
                )
                #expect(testCase.expected == .status(path.backing))
            } catch let WaylandGraphicsError.unavailable(reason) {
                #expect(testCase.expected == .error(reason))
            }
        }
    }

    @Test
    func presentationPolicyMutationCannotSplitModeFromFallback() throws {
        var configuration = WaylandGraphicsConfiguration(
            presentationPolicy: .externalGPU(fallback: .unavailable)
        )

        configuration.presentationPolicy = .managedGPU(fallback: .software)

        #expect(configuration.presentationPolicy == .managedGPU(fallback: .software))
        let path = try WaylandDisplay.managedPreviewRuntimePath(
            capabilities: gpuCapableSurfaceCapabilities(),
            configuration: configuration
        )
        #expect(path.backing == .advertised)
    }

    @Test
    func requireExplicitRejectsSoftwarePolicy() {
        #expect(
            throws: WaylandGraphicsError.unavailable(
                .managedGPUSubmissionUnavailable
            )
        ) {
            _ = try WaylandDisplay.managedPreviewRuntimePath(
                capabilities: gpuCapableSurfaceCapabilities(),
                configuration: WaylandGraphicsConfiguration(
                    presentationPolicy: .software,
                    synchronizationPolicy: .requireExplicit
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

private struct PolicyRuntimePathCase: Sendable {
    let policy: WaylandGraphicsPresentationPolicy
    let capabilities: WaylandGraphicsSurfaceCapabilities
    let expected: PolicyRuntimePathExpectation
}

private enum PolicyRuntimePathExpectation: Equatable, Sendable {
    case status(WaylandGraphicsRuntimeStatus)
    case error(WaylandGraphicsReason)
}

private let policyRuntimePathCases: [PolicyRuntimePathCase] = [
    PolicyRuntimePathCase(
        policy: .software,
        capabilities: gpuCapableSurfaceCapabilities(),
        expected: .status(.fallback(.forcedSoftware))
    ),
    PolicyRuntimePathCase(
        policy: .software,
        capabilities: softwareOnlySurfaceCapabilities(),
        expected: .status(.fallback(.forcedSoftware))
    ),
    PolicyRuntimePathCase(
        policy: .managedGPU(fallback: .software),
        capabilities: gpuCapableSurfaceCapabilities(),
        expected: .status(.advertised)
    ),
    PolicyRuntimePathCase(
        policy: .managedGPU(fallback: .software),
        capabilities: softwareOnlySurfaceCapabilities(),
        expected: .status(.fallback(.dmabufUnavailable))
    ),
    PolicyRuntimePathCase(
        policy: .managedGPU(fallback: .unavailable),
        capabilities: gpuCapableSurfaceCapabilities(),
        expected: .status(.advertised)
    ),
    PolicyRuntimePathCase(
        policy: .managedGPU(fallback: .unavailable),
        capabilities: softwareOnlySurfaceCapabilities(),
        expected: .error(.dmabufUnavailable)
    ),
    PolicyRuntimePathCase(
        policy: .externalGPU(fallback: .software),
        capabilities: gpuCapableSurfaceCapabilities(),
        expected: .status(.advertised)
    ),
    PolicyRuntimePathCase(
        policy: .externalGPU(fallback: .software),
        capabilities: softwareOnlySurfaceCapabilities(),
        expected: .status(.fallback(.dmabufUnavailable))
    ),
    PolicyRuntimePathCase(
        policy: .externalGPU(fallback: .unavailable),
        capabilities: gpuCapableSurfaceCapabilities(),
        expected: .status(.advertised)
    ),
    PolicyRuntimePathCase(
        policy: .externalGPU(fallback: .unavailable),
        capabilities: softwareOnlySurfaceCapabilities(),
        expected: .error(.dmabufUnavailable)
    ),
]
