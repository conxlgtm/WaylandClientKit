import WaylandClient

extension WaylandDisplay {
    /// Returns renderer-neutral graphics preview capabilities discovered so far.
    public func graphicsSurfaceCapabilities() throws -> WaylandGraphicsSurfaceCapabilities {
        try WaylandGraphicsSurfaceCapabilities(
            snapshot: graphicsPreviewSurfaceCapabilitySnapshot()
        )
    }

    /// Returns a projected graphics runtime path without creating GPU resources.
    public func graphicsRuntimePath(
        policy: WaylandGraphicsFallbackPolicy = .preferGPUFallbackToSoftware
    ) throws -> WaylandGraphicsRuntimePath {
        try WaylandGraphicsRuntimePath.projected(
            capabilities: graphicsSurfaceCapabilities(),
            policy: policy
        )
    }

    /// Returns the projected graphics backing decision without creating GPU resources.
    public func graphicsBackingDecision(
        policy: WaylandGraphicsFallbackPolicy = .preferGPUFallbackToSoftware
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
            configuration: graphicsConfiguration
        )
        return WaylandGraphicsWindowBacking(window: window, storage: storage)
    }

    package static func managedPreviewRuntimePath(
        capabilities: WaylandGraphicsSurfaceCapabilities,
        configuration: WaylandGraphicsConfiguration
    ) throws -> WaylandGraphicsRuntimePath {
        try configuration.validateManagedPreviewSupport(capabilities: capabilities)

        switch configuration.backingPreference {
        case .software:
            return .softwareFallback(capabilities: capabilities, reason: .forcedSoftware)
        case .managedGPU:
            break
        }

        switch configuration.fallbackPolicy {
        case .forceSoftware:
            return .softwareFallback(capabilities: capabilities, reason: .forcedSoftware)
        case .preferGPUFallbackToSoftware where !capabilities.dmabuf.isAvailable:
            return .softwareFallback(capabilities: capabilities, reason: .dmabufUnavailable)
        case .requireGPU where !capabilities.dmabuf.isAvailable:
            throw WaylandGraphicsError.unavailable(.dmabufUnavailable)
        case .preferGPUFallbackToSoftware:
            return .softwareFallback(
                capabilities: capabilities,
                reason: .managedGPUSubmissionUnavailable
            )
        case .requireGPU:
            throw WaylandGraphicsError.unavailable(.managedGPUSubmissionUnavailable)
        }
    }
}
