import Testing
import WaylandClient
import WaylandGraphicsPreview
import WaylandRaw

@Suite
struct WaylandGraphicsPreviewCapabilityBridgeTests {
    @Test
    func surfaceSnapshotMapsExplicitSyncVersion() {
        let capabilities = publicCapabilities(
            from: surfaceSnapshot(
                synchronization: .explicitAvailable(version: 3)
            )
        )

        #expect(capabilities.explicitSync == .available(version: 3))
    }

    @Test
    func surfaceSnapshotMapsFifoAndCommitTimingVersions() {
        let capabilities = publicCapabilities(
            from: surfaceSnapshot(
                pacing: .fifoAndCommitTiming(fifo: 2, commitTiming: 4)
            )
        )

        #expect(capabilities.framePacing.fifo == .available(version: 2))
        #expect(capabilities.framePacing.commitTiming == .available(version: 4))
    }

    @Test
    func surfaceSnapshotMapsPendingColorRepresentation() {
        let capabilities = publicCapabilities(
            from: surfaceSnapshot(
                colorRepresentation: .pending(version: 5)
            )
        )

        #expect(capabilities.colorMetadata.colorRepresentation == .pending(version: 5))
    }

    @Test
    func surfaceSnapshotMapsPreferredColorDescriptionAsAvailable() throws {
        let reference = try SurfaceColorDescriptionReference(identity: 7)
        let capabilities = publicCapabilities(
            from: surfaceSnapshot(
                color: .preferredDescription(reference)
            )
        )

        #expect(capabilities.colorMetadata.colorManagement == .available(version: 1))
    }

    @Test
    func surfaceSnapshotMapsDmabufAdvertisementVersion() {
        let capabilities = publicCapabilities(
            from: surfaceSnapshot(
                dmabuf: .advertised(version: 6, canRequestSurfaceFeedback: .available)
            )
        )

        #expect(capabilities.dmabuf == .available(version: 6))
    }

    @Test
    func surfaceSnapshotMapsSurfaceFeedbackVersion() throws {
        let surfaceID = RawObjectID(42)
        let feedback = try SurfaceDmabufFeedback(
            snapshot: feedbackSnapshot(scope: .surface(surfaceID: surfaceID)),
            surfaceID: surfaceID
        )
        let capabilities = publicCapabilities(
            from: surfaceSnapshot(
                dmabuf: .surfaceFeedback(
                    version: 6,
                    feedback: feedback
                )
            )
        )

        #expect(capabilities.dmabuf == .available(version: 6))
    }
}

private func publicCapabilities(
    from snapshot: SurfaceCapabilitySnapshot
) -> WaylandGraphicsSurfaceCapabilities {
    WaylandGraphicsSurfaceCapabilities(
        snapshot: GraphicsPreviewSurfaceCapabilitySnapshot(snapshot: snapshot)
    )
}

private func surfaceSnapshot(
    presentationFeedback: SurfaceCapabilityStatus = .unavailable,
    dmabuf: SurfaceDmabufCapability = .unavailable,
    synchronization: SurfaceSynchronizationCapability = .implicitOnly,
    pacing: SurfacePacingCapability = .unavailable,
    contentType: SurfaceCapabilityStatus = .unavailable,
    alphaModifier: SurfaceCapabilityStatus = .unavailable,
    tearingControl: SurfaceCapabilityStatus = .unavailable,
    colorRepresentation: SurfaceColorRepresentationCapability = .unavailable,
    color: SurfaceColorCapability = .unavailable
) -> SurfaceCapabilitySnapshot {
    SurfaceCapabilitySnapshot(
        role: .toplevelWindow,
        outputIDs: [],
        fractionalScale: .integerOnly,
        presentationFeedback: presentationFeedback,
        dmabuf: dmabuf,
        synchronization: synchronization,
        pacing: pacing,
        contentType: contentType,
        alphaModifier: alphaModifier,
        tearingControl: tearingControl,
        colorRepresentation: colorRepresentation,
        color: color
    )
}

private func feedbackSnapshot(
    scope: RawLinuxDmabufFeedbackScope
) throws -> RawLinuxDmabufFeedbackSnapshot {
    let formatModifier = RawLinuxDmabufFormatModifier(
        format: 875_713_112,
        modifier: 0
    )
    var state = RawLinuxDmabufFeedbackState()

    state.replaceFormatTable([formatModifier])
    try state.setMainDevice(bytes: [1, 2, 3, 4, 5, 6, 7, 8], scope: scope)
    try state.setCurrentTrancheTargetDevice(
        bytes: [1, 2, 3, 4, 5, 6, 7, 8],
        scope: scope
    )
    try state.setCurrentTrancheFlags(
        RawLinuxDmabufTrancheFlags.scanout.rawValue,
        scope: scope
    )
    try state.appendCurrentTrancheFormats(indices: [0], scope: scope)
    try state.finishCurrentTranche(scope: scope)
    return try state.finish(scope: scope)
}
