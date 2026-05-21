package enum GraphicsPreviewProtocolCapability: Equatable, Sendable {
    case unavailable
    case pending(version: UInt32)
    case available(version: UInt32)
}

package struct GraphicsPreviewFramePacingCapabilities: Equatable, Sendable {
    package let fifo: GraphicsPreviewProtocolCapability
    package let commitTiming: GraphicsPreviewProtocolCapability

    package init(
        fifo: GraphicsPreviewProtocolCapability,
        commitTiming: GraphicsPreviewProtocolCapability
    ) {
        self.fifo = fifo
        self.commitTiming = commitTiming
    }
}

package struct GraphicsPreviewMetadataCapabilities: Equatable, Sendable {
    package let contentType: GraphicsPreviewProtocolCapability
    package let alphaModifier: GraphicsPreviewProtocolCapability
    package let tearingControl: GraphicsPreviewProtocolCapability
    package let colorRepresentation: GraphicsPreviewProtocolCapability
    package let colorManagement: GraphicsPreviewProtocolCapability

    package init(
        contentType: GraphicsPreviewProtocolCapability,
        alphaModifier: GraphicsPreviewProtocolCapability,
        tearingControl: GraphicsPreviewProtocolCapability,
        colorRepresentation: GraphicsPreviewProtocolCapability,
        colorManagement: GraphicsPreviewProtocolCapability
    ) {
        self.contentType = contentType
        self.alphaModifier = alphaModifier
        self.tearingControl = tearingControl
        self.colorRepresentation = colorRepresentation
        self.colorManagement = colorManagement
    }
}

package struct GraphicsPreviewSurfaceCapabilitySnapshot: Equatable, Sendable {
    package let dmabuf: GraphicsPreviewProtocolCapability
    package let explicitSync: GraphicsPreviewProtocolCapability
    package let framePacing: GraphicsPreviewFramePacingCapabilities
    package let metadata: GraphicsPreviewMetadataCapabilities
    package let presentationFeedback: GraphicsPreviewProtocolCapability

    package init(snapshot: SurfaceCapabilitySnapshot) {
        dmabuf = Self.dmabufCapability(snapshot.dmabuf)
        explicitSync = Self.synchronizationCapability(snapshot.synchronization)
        framePacing = Self.pacingCapabilities(snapshot.pacing)
        metadata = GraphicsPreviewMetadataCapabilities(
            contentType: Self.capabilityStatus(snapshot.contentType),
            alphaModifier: Self.capabilityStatus(snapshot.alphaModifier),
            tearingControl: Self.capabilityStatus(snapshot.tearingControl),
            colorRepresentation: Self.colorRepresentationCapability(
                snapshot.colorRepresentation
            ),
            colorManagement: Self.colorCapability(snapshot.color)
        )
        presentationFeedback = Self.capabilityStatus(snapshot.presentationFeedback)
    }

    private static func capabilityStatus(
        _ status: SurfaceCapabilityStatus
    ) -> GraphicsPreviewProtocolCapability {
        switch status {
        case .unavailable:
            .unavailable
        case .available:
            .available(version: 1)
        }
    }

    private static func dmabufCapability(
        _ capability: SurfaceDmabufCapability
    ) -> GraphicsPreviewProtocolCapability {
        switch capability {
        case .unavailable:
            .unavailable
        case .advertised(let version, _):
            .available(version: version.value)
        case .surfaceFeedback:
            .available(version: 1)
        }
    }

    private static func synchronizationCapability(
        _ capability: SurfaceSynchronizationCapability
    ) -> GraphicsPreviewProtocolCapability {
        switch capability {
        case .implicitOnly:
            .unavailable
        case .explicitAvailable(let version):
            .available(version: version.value)
        case .explicitActive:
            .available(version: 1)
        }
    }

    private static func pacingCapabilities(
        _ capability: SurfacePacingCapability
    ) -> GraphicsPreviewFramePacingCapabilities {
        switch capability {
        case .unavailable:
            GraphicsPreviewFramePacingCapabilities(
                fifo: .unavailable,
                commitTiming: .unavailable
            )
        case .fifo(let fifo):
            GraphicsPreviewFramePacingCapabilities(
                fifo: .available(version: fifo.value),
                commitTiming: .unavailable
            )
        case .commitTiming(let commitTiming):
            GraphicsPreviewFramePacingCapabilities(
                fifo: .unavailable,
                commitTiming: .available(version: commitTiming.value)
            )
        case .fifoAndCommitTiming(let fifo, let commitTiming):
            GraphicsPreviewFramePacingCapabilities(
                fifo: .available(version: fifo.value),
                commitTiming: .available(version: commitTiming.value)
            )
        }
    }

    private static func colorRepresentationCapability(
        _ capability: SurfaceColorRepresentationCapability
    ) -> GraphicsPreviewProtocolCapability {
        switch capability {
        case .unavailable:
            .unavailable
        case .pending(let version):
            .pending(version: version.value)
        case .available(let version, _):
            .available(version: version.value)
        }
    }

    private static func colorCapability(
        _ capability: SurfaceColorCapability
    ) -> GraphicsPreviewProtocolCapability {
        switch capability {
        case .unavailable:
            .unavailable
        case .available(let version):
            .available(version: version.value)
        case .preferredDescription:
            .available(version: 1)
        }
    }
}

extension WaylandDisplay {
    package func graphicsPreviewSurfaceCapabilitySnapshot()
        throws -> GraphicsPreviewSurfaceCapabilitySnapshot
    {
        try GraphicsPreviewSurfaceCapabilitySnapshot(
            snapshot: requireCore().graphicsPreviewSurfaceCapabilitySnapshot()
        )
    }
}

extension DisplayCore {
    func graphicsPreviewSurfaceCapabilitySnapshot() throws -> SurfaceCapabilitySnapshot {
        try withFatalFailureFinalization {
            try requireSession().graphicsPreviewSurfaceCapabilitySnapshotOnOwnerThread()
        }
    }
}

extension DisplaySession {
    package func graphicsPreviewSurfaceCapabilitySnapshotOnOwnerThread()
        throws -> SurfaceCapabilitySnapshot
    {
        connection.preconditionIsOwnerThread()
        let globals = try connection.bindRequiredGlobals()
        var runtime = SurfaceRuntime<Void>(role: .toplevelWindow)
        runtime.setPresentationFeedbackCapability(
            globals.extensions.presentation.presentationFeedbackCapabilityStatus
        )
        runtime.setDmabufAdvertisement(
            globals.extensions.linuxDmabuf.surfaceDmabufAdvertisement
        )
        runtime.setSynchronizationCapability(
            globals.extensions.surfaceSynchronizationCapability
        )
        runtime.setPacingCapability(globals.extensions.surfacePacingCapability)
        runtime.setContentTypeCapability(
            globals.extensions.surfaceContentTypeCapability
        )
        runtime.setAlphaModifierCapability(
            globals.extensions.surfaceAlphaModifierCapability
        )
        runtime.setTearingControlCapability(
            globals.extensions.surfaceTearingControlCapability
        )
        runtime.setColorRepresentationCapability(
            globals.extensions.surfaceColorRepresentationCapability
        )
        runtime.setColorCapability(globals.extensions.surfaceColorCapability)
        return runtime.capabilitySnapshot()
    }
}
