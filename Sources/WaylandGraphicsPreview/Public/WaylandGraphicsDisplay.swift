import WaylandClient
import WaylandGPUPreview

extension WaylandDisplay {
    /// Returns renderer-neutral graphics preview capabilities discovered so far.
    public func graphicsSurfaceCapabilities() throws -> WaylandGraphicsSurfaceCapabilities {
        try WaylandGraphicsSurfaceCapabilities(
            snapshot: graphicsPreviewSurfaceCapabilitySnapshot()
        )
    }

    /// Returns a projected graphics runtime path without creating GPU resources.
    public func graphicsRuntimePath(
        policy: WaylandGraphicsPresentationPolicy = .managedGPU(fallback: .software)
    ) throws -> WaylandGraphicsRuntimePath {
        try WaylandGraphicsRuntimePath.projected(
            capabilities: graphicsSurfaceCapabilities(),
            policy: policy
        )
    }

    /// Returns the projected graphics backing decision without creating GPU resources.
    public func graphicsBackingDecision(
        policy: WaylandGraphicsPresentationPolicy = .managedGPU(fallback: .software)
    ) throws -> WaylandGraphicsBackingDecision {
        try policy.decide(capabilities: graphicsSurfaceCapabilities())
    }

    public func createGraphicsWindowBacking(
        windowConfiguration: WindowConfiguration = .default,
        graphicsConfiguration: WaylandGraphicsConfiguration = .default
    ) throws -> WaylandGraphicsWindowBacking {
        let capabilities = try graphicsSurfaceCapabilities()
        let runtimePath = try Self.managedPreviewRuntimePath(
            capabilities: capabilities,
            configuration: graphicsConfiguration
        )
        let window = try createTopLevelWindow(configuration: windowConfiguration)
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: runtimePath,
            configuration: graphicsConfiguration,
            managedGPUBacking: Self.shouldCreateManagedGPUBacking(
                runtimePath: runtimePath,
                configuration: graphicsConfiguration
            ) ? ManagedGPUPreviewBacking(window: window) : nil
        )
        registerWindowCloseObserver(for: window.id) { [weak storage] in
            await storage?.closeBecauseWindowClosed()
        }
        return WaylandGraphicsWindowBacking(window: window, storage: storage)
    }

    package static func managedPreviewRuntimePath(
        capabilities: WaylandGraphicsSurfaceCapabilities,
        configuration: WaylandGraphicsConfiguration
    ) throws -> WaylandGraphicsRuntimePath {
        try configuration.validateManagedPreviewSupport(capabilities: capabilities)

        switch configuration.presentationPolicy {
        case .software:
            return .softwareFallback(capabilities: capabilities, reason: .forcedSoftware)
        case .managedGPU(let fallback), .externalGPU(let fallback):
            guard !capabilities.dmabuf.isAvailable else {
                return .projected(
                    capabilities: capabilities,
                    policy: configuration.presentationPolicy
                )
            }
            switch fallback {
            case .software:
                return .softwareFallback(
                    capabilities: capabilities,
                    reason: .dmabufUnavailable
                )
            case .unavailable:
                throw WaylandGraphicsError.unavailable(.dmabufUnavailable)
            }
        }
    }

    private static func shouldCreateManagedGPUBacking(
        runtimePath: WaylandGraphicsRuntimePath,
        configuration: WaylandGraphicsConfiguration
    ) -> Bool {
        guard case .managedGPU = configuration.presentationPolicy else {
            return false
        }

        return runtimePath.backing == .advertised
    }
}
