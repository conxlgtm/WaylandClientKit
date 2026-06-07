import WaylandClient

/// Protocol availability as seen by the graphics preview API.
public enum WaylandGraphicsProtocolAvailability: Equatable, Sendable {
    case unavailable
    case pending(version: UInt32)
    case available(version: UInt32)

    public init(_ availability: ProtocolAvailability) {
        switch availability {
        case .unavailable:
            self = .unavailable
        case .available(let version):
            self = .available(version: version)
        }
    }

    public var isAvailable: Bool {
        switch self {
        case .unavailable, .pending:
            false
        case .available:
            true
        }
    }

    public var version: UInt32? {
        switch self {
        case .unavailable:
            nil
        case .pending(let version):
            version
        case .available(let version):
            version
        }
    }
}

/// Frame pacing protocol availability for a graphics-capable surface.
public struct WaylandGraphicsFramePacingAvailability: Equatable, Sendable {
    public let fifo: WaylandGraphicsProtocolAvailability
    public let commitTiming: WaylandGraphicsProtocolAvailability

    public static let unavailable = Self(
        fifo: .unavailable,
        commitTiming: .unavailable
    )

    public init(
        fifo: WaylandGraphicsProtocolAvailability,
        commitTiming: WaylandGraphicsProtocolAvailability
    ) {
        self.fifo = fifo
        self.commitTiming = commitTiming
    }
}

/// Surface metadata protocol availability for the graphics preview API.
public struct WaylandGraphicsColorMetadataAvailability: Equatable, Sendable {
    public let contentType: WaylandGraphicsProtocolAvailability
    public let alphaModifier: WaylandGraphicsProtocolAvailability
    public let tearingControl: WaylandGraphicsProtocolAvailability
    public let colorRepresentation: WaylandGraphicsProtocolAvailability
    public let colorManagement: WaylandGraphicsProtocolAvailability

    public static let unavailable = Self(
        contentType: .unavailable,
        alphaModifier: .unavailable,
        tearingControl: .unavailable,
        colorRepresentation: .unavailable,
        colorManagement: .unavailable
    )

    public init(
        contentType: WaylandGraphicsProtocolAvailability,
        alphaModifier: WaylandGraphicsProtocolAvailability,
        tearingControl: WaylandGraphicsProtocolAvailability,
        colorRepresentation: WaylandGraphicsProtocolAvailability,
        colorManagement: WaylandGraphicsProtocolAvailability
    ) {
        self.contentType = contentType
        self.alphaModifier = alphaModifier
        self.tearingControl = tearingControl
        self.colorRepresentation = colorRepresentation
        self.colorManagement = colorManagement
    }
}

/// Renderer-neutral compositor facts relevant to graphics backing.
public struct WaylandGraphicsSurfaceCapabilities: Equatable, Sendable {
    public let dmabuf: WaylandGraphicsProtocolAvailability
    public let explicitSync: WaylandGraphicsProtocolAvailability
    public let framePacing: WaylandGraphicsFramePacingAvailability
    public let colorMetadata: WaylandGraphicsColorMetadataAvailability
    public let presentationFeedback: WaylandGraphicsProtocolAvailability

    public init(
        dmabuf: WaylandGraphicsProtocolAvailability,
        explicitSync: WaylandGraphicsProtocolAvailability,
        framePacing: WaylandGraphicsFramePacingAvailability,
        colorMetadata: WaylandGraphicsColorMetadataAvailability,
        presentationFeedback: WaylandGraphicsProtocolAvailability
    ) {
        self.dmabuf = dmabuf
        self.explicitSync = explicitSync
        self.framePacing = framePacing
        self.colorMetadata = colorMetadata
        self.presentationFeedback = presentationFeedback
    }

    public init(capabilities: WaylandCapabilities) {
        self.init(
            dmabuf: WaylandGraphicsProtocolAvailability(capabilities.linuxDmabuf),
            explicitSync: .unavailable,
            framePacing: .unavailable,
            colorMetadata: .unavailable,
            presentationFeedback: WaylandGraphicsProtocolAvailability(
                capabilities.presentationTime
            )
        )
    }

    package init(snapshot: GraphicsPreviewSurfaceCapabilitySnapshot) {
        self.init(
            dmabuf: WaylandGraphicsProtocolAvailability(snapshot.dmabuf),
            explicitSync: WaylandGraphicsProtocolAvailability(snapshot.explicitSync),
            framePacing: WaylandGraphicsFramePacingAvailability(
                fifo: WaylandGraphicsProtocolAvailability(snapshot.framePacing.fifo),
                commitTiming: WaylandGraphicsProtocolAvailability(
                    snapshot.framePacing.commitTiming
                )
            ),
            colorMetadata: WaylandGraphicsColorMetadataAvailability(
                contentType: WaylandGraphicsProtocolAvailability(
                    snapshot.metadata.contentType
                ),
                alphaModifier: WaylandGraphicsProtocolAvailability(
                    snapshot.metadata.alphaModifier
                ),
                tearingControl: WaylandGraphicsProtocolAvailability(
                    snapshot.metadata.tearingControl
                ),
                colorRepresentation: WaylandGraphicsProtocolAvailability(
                    snapshot.metadata.colorRepresentation
                ),
                colorManagement: WaylandGraphicsProtocolAvailability(
                    snapshot.metadata.colorManagement
                )
            ),
            presentationFeedback: WaylandGraphicsProtocolAvailability(
                snapshot.presentationFeedback
            )
        )
    }
}

extension WaylandGraphicsProtocolAvailability {
    package init(_ capability: GraphicsPreviewProtocolCapability) {
        switch capability {
        case .unavailable:
            self = .unavailable
        case .pending(let version):
            self = .pending(version: version)
        case .available(let version):
            self = .available(version: version)
        }
    }
}

/// Policy for choosing between GPU backing and software fallback.
public enum WaylandGraphicsFallbackPolicy: Equatable, Sendable {
    case preferGPUFallbackToSoftware
    case requireGPU
    case forceSoftware

    public func decide(
        capabilities: WaylandGraphicsSurfaceCapabilities
    ) -> WaylandGraphicsBackingDecision {
        switch self {
        case .forceSoftware:
            return .software(.forcedSoftware)
        case .preferGPUFallbackToSoftware where !capabilities.dmabuf.isAvailable:
            return .software(.dmabufUnavailable)
        case .requireGPU where !capabilities.dmabuf.isAvailable:
            return .unavailable(.dmabufUnavailable)
        case .preferGPUFallbackToSoftware, .requireGPU:
            return .gpu(
                WaylandGraphicsRuntimePath.projected(
                    capabilities: capabilities,
                    policy: self
                )
            )
        }
    }

    public func decide(capabilities: WaylandCapabilities) -> WaylandGraphicsBackingDecision {
        decide(capabilities: WaylandGraphicsSurfaceCapabilities(capabilities: capabilities))
    }
}

/// Reasons a graphics preview path can select software fallback.
public enum WaylandGraphicsFallbackReason: Equatable, Sendable {
    case forcedSoftware
    case dmabufUnavailable
    case managedGPUSubmissionUnavailable
    case noCompatibleFormat
    case noRenderNode
    case gbmUnavailable
    case eglUnavailable
    case explicitSyncRequiredButUnavailable
    case metadataRequiredButUnavailable
    case presentationFeedbackUnavailable
    case compositorRejectedBuffer
    case surfaceFeedbackUnavailable
    case gbmAllocationFailed
}

/// Reasons GPU backing can be unavailable.
public enum WaylandGraphicsUnavailableReason: Equatable, Sendable {
    case dmabufUnavailable
    case managedGPUSubmissionUnavailable
    case noCompatibleFormat
    case noRenderNode
    case gbmUnavailable
    case eglUnavailable
    case explicitSyncRequiredButUnavailable
    case metadataRequiredButUnavailable
    case presentationFeedbackUnavailable
    case compositorRejectedBuffer
    case surfaceFeedbackUnavailable
    case gbmAllocationFailed
}

/// Renderer-neutral backing decision for a graphics-capable surface.
public enum WaylandGraphicsBackingDecision: Equatable, Sendable {
    case gpu(WaylandGraphicsRuntimePath)
    case software(WaylandGraphicsFallbackReason)
    case unavailable(WaylandGraphicsUnavailableReason)
}

/// Runtime status for one graphics path component.
public enum WaylandGraphicsRuntimeStatus: Equatable, Sendable {
    case unavailable
    case pending
    case advertised
    case configured
    case active
    case failed(WaylandGraphicsUnavailableReason)
    case fallback(WaylandGraphicsFallbackReason)
}

/// Runtime status for frame pacing paths.
public struct WaylandGraphicsPacingStatus: Equatable, Sendable {
    public let fifo: WaylandGraphicsRuntimeStatus
    public let commitTiming: WaylandGraphicsRuntimeStatus

    public init(
        fifo: WaylandGraphicsRuntimeStatus,
        commitTiming: WaylandGraphicsRuntimeStatus
    ) {
        self.fifo = fifo
        self.commitTiming = commitTiming
    }
}

/// Runtime status for surface metadata paths.
public struct WaylandGraphicsMetadataStatus: Equatable, Sendable {
    public let contentType: WaylandGraphicsRuntimeStatus
    public let alphaModifier: WaylandGraphicsRuntimeStatus
    public let tearingControl: WaylandGraphicsRuntimeStatus
    public let colorRepresentation: WaylandGraphicsRuntimeStatus
    public let colorManagement: WaylandGraphicsRuntimeStatus

    public init(
        contentType: WaylandGraphicsRuntimeStatus,
        alphaModifier: WaylandGraphicsRuntimeStatus,
        tearingControl: WaylandGraphicsRuntimeStatus,
        colorRepresentation: WaylandGraphicsRuntimeStatus,
        colorManagement: WaylandGraphicsRuntimeStatus
    ) {
        self.contentType = contentType
        self.alphaModifier = alphaModifier
        self.tearingControl = tearingControl
        self.colorRepresentation = colorRepresentation
        self.colorManagement = colorManagement
    }
}

/// Read-only graphics preview runtime path.
public struct WaylandGraphicsRuntimePath: Equatable, Sendable {
    public let capabilities: WaylandGraphicsSurfaceCapabilities
    public let backing: WaylandGraphicsRuntimeStatus
    public let dmabuf: WaylandGraphicsRuntimeStatus
    public let gbm: WaylandGraphicsRuntimeStatus
    public let egl: WaylandGraphicsRuntimeStatus
    public let explicitSync: WaylandGraphicsRuntimeStatus
    public let pacing: WaylandGraphicsPacingStatus
    public let metadata: WaylandGraphicsMetadataStatus
    public let presentationFeedback: WaylandGraphicsRuntimeStatus
    public var fallback: WaylandGraphicsFallbackReason? {
        guard case .fallback(let reason) = backing else {
            return nil
        }

        return reason
    }

    package init(
        capabilities: WaylandGraphicsSurfaceCapabilities,
        backing: WaylandGraphicsRuntimeStatus,
        dmabuf: WaylandGraphicsRuntimeStatus,
        gbm: WaylandGraphicsRuntimeStatus,
        egl: WaylandGraphicsRuntimeStatus,
        explicitSync: WaylandGraphicsRuntimeStatus,
        pacing: WaylandGraphicsPacingStatus,
        metadata: WaylandGraphicsMetadataStatus,
        presentationFeedback: WaylandGraphicsRuntimeStatus
    ) {
        self.capabilities = capabilities
        self.backing = backing
        self.dmabuf = dmabuf
        self.gbm = gbm
        self.egl = egl
        self.explicitSync = explicitSync
        self.pacing = pacing
        self.metadata = metadata
        self.presentationFeedback = presentationFeedback
    }

    public static func projected(
        capabilities: WaylandCapabilities,
        policy: WaylandGraphicsFallbackPolicy = .preferGPUFallbackToSoftware
    ) -> Self {
        projected(
            capabilities: WaylandGraphicsSurfaceCapabilities(capabilities: capabilities),
            policy: policy
        )
    }

    public static func projected(
        capabilities: WaylandGraphicsSurfaceCapabilities,
        policy: WaylandGraphicsFallbackPolicy = .preferGPUFallbackToSoftware
    ) -> Self {
        let fallback = fallbackReason(
            capabilities: capabilities,
            policy: policy
        )
        let unavailable = unavailableReason(
            capabilities: capabilities,
            policy: policy
        )
        return Self(
            capabilities: capabilities,
            backing: backingStatus(fallback: fallback, unavailable: unavailable),
            dmabuf: protocolStatus(
                capabilities.dmabuf,
                fallback: fallback,
                unavailable: unavailable
            ),
            gbm: .unavailable,
            egl: .unavailable,
            explicitSync: protocolStatus(capabilities.explicitSync),
            pacing: WaylandGraphicsPacingStatus(
                fifo: protocolStatus(capabilities.framePacing.fifo),
                commitTiming: protocolStatus(capabilities.framePacing.commitTiming)
            ),
            metadata: WaylandGraphicsMetadataStatus(
                contentType: protocolStatus(capabilities.colorMetadata.contentType),
                alphaModifier: protocolStatus(capabilities.colorMetadata.alphaModifier),
                tearingControl: protocolStatus(capabilities.colorMetadata.tearingControl),
                colorRepresentation: protocolStatus(
                    capabilities.colorMetadata.colorRepresentation
                ),
                colorManagement: protocolStatus(capabilities.colorMetadata.colorManagement)
            ),
            presentationFeedback: protocolStatus(capabilities.presentationFeedback)
        )
    }

    public static func softwareFallback(
        capabilities: WaylandGraphicsSurfaceCapabilities,
        reason: WaylandGraphicsFallbackReason
    ) -> Self {
        Self(
            capabilities: capabilities,
            backing: .fallback(reason),
            dmabuf: capabilities.dmabuf.isAvailable
                ? protocolStatus(capabilities.dmabuf)
                : .fallback(reason),
            gbm: .fallback(reason),
            egl: .fallback(reason),
            explicitSync: protocolStatus(capabilities.explicitSync),
            pacing: WaylandGraphicsPacingStatus(
                fifo: protocolStatus(capabilities.framePacing.fifo),
                commitTiming: protocolStatus(capabilities.framePacing.commitTiming)
            ),
            metadata: WaylandGraphicsMetadataStatus(
                contentType: protocolStatus(capabilities.colorMetadata.contentType),
                alphaModifier: protocolStatus(capabilities.colorMetadata.alphaModifier),
                tearingControl: protocolStatus(capabilities.colorMetadata.tearingControl),
                colorRepresentation: protocolStatus(
                    capabilities.colorMetadata.colorRepresentation
                ),
                colorManagement: protocolStatus(capabilities.colorMetadata.colorManagement)
            ),
            presentationFeedback: protocolStatus(capabilities.presentationFeedback)
        )
    }

    public static func unavailable(
        capabilities: WaylandGraphicsSurfaceCapabilities,
        reason: WaylandGraphicsUnavailableReason
    ) -> Self {
        Self(
            capabilities: capabilities,
            backing: .failed(reason),
            dmabuf: capabilities.dmabuf.isAvailable
                ? protocolStatus(capabilities.dmabuf)
                : .failed(reason),
            gbm: .failed(reason),
            egl: .failed(reason),
            explicitSync: protocolStatus(capabilities.explicitSync),
            pacing: WaylandGraphicsPacingStatus(
                fifo: protocolStatus(capabilities.framePacing.fifo),
                commitTiming: protocolStatus(capabilities.framePacing.commitTiming)
            ),
            metadata: WaylandGraphicsMetadataStatus(
                contentType: protocolStatus(capabilities.colorMetadata.contentType),
                alphaModifier: protocolStatus(capabilities.colorMetadata.alphaModifier),
                tearingControl: protocolStatus(capabilities.colorMetadata.tearingControl),
                colorRepresentation: protocolStatus(
                    capabilities.colorMetadata.colorRepresentation
                ),
                colorManagement: protocolStatus(capabilities.colorMetadata.colorManagement)
            ),
            presentationFeedback: protocolStatus(capabilities.presentationFeedback)
        )
    }

    private static func protocolStatus(
        _ availability: WaylandGraphicsProtocolAvailability,
        fallback: WaylandGraphicsFallbackReason? = nil,
        unavailable: WaylandGraphicsUnavailableReason? = nil
    ) -> WaylandGraphicsRuntimeStatus {
        if let unavailable {
            return .failed(unavailable)
        }
        if let fallback {
            return .fallback(fallback)
        }
        switch availability {
        case .unavailable:
            return .unavailable
        case .pending:
            return .pending
        case .available:
            return .advertised
        }
    }

    private static func backingStatus(
        fallback: WaylandGraphicsFallbackReason?,
        unavailable: WaylandGraphicsUnavailableReason?
    ) -> WaylandGraphicsRuntimeStatus {
        if let unavailable {
            return .failed(unavailable)
        }
        if let fallback {
            return .fallback(fallback)
        }
        return .advertised
    }

    private static func fallbackReason(
        capabilities: WaylandGraphicsSurfaceCapabilities,
        policy: WaylandGraphicsFallbackPolicy
    ) -> WaylandGraphicsFallbackReason? {
        switch policy {
        case .forceSoftware:
            return .forcedSoftware
        case .preferGPUFallbackToSoftware where !capabilities.dmabuf.isAvailable:
            return .dmabufUnavailable
        case .preferGPUFallbackToSoftware, .requireGPU:
            return nil
        }
    }

    private static func unavailableReason(
        capabilities: WaylandGraphicsSurfaceCapabilities,
        policy: WaylandGraphicsFallbackPolicy
    ) -> WaylandGraphicsUnavailableReason? {
        switch policy {
        case .requireGPU where !capabilities.dmabuf.isAvailable:
            return .dmabufUnavailable
        case .preferGPUFallbackToSoftware, .requireGPU, .forceSoftware:
            return nil
        }
    }
}
