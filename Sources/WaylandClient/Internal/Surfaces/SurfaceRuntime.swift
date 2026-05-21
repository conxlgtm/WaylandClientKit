// swiftlint:disable file_length
import WaylandRaw

extension OptionalPresentation {
    var presentationFeedbackCapabilityStatus: SurfaceCapabilityStatus {
        switch self {
        case .bound:
            .available
        case .missing:
            .unavailable
        }
    }
}

enum SurfaceRuntimeError: Error, Equatable {
    case surfaceDestroyedWithActiveBufferPool
    case surfaceDestroyedWithLiveRoleResources
    case installAfterSurfaceDestroyed
    case installAfterRoleDestroyed(role: SurfaceRuntimeRole)
    case roleResourcesAlreadyInstalled(role: SurfaceRuntimeRole)
}

package enum SurfaceRuntimeRole: Equatable, Sendable {
    case toplevelWindow
    case popup
    case cursor
    case dragIcon
}

package enum SurfaceCapabilityStatus: Equatable, Sendable {
    case unavailable
    case available
}

package enum SurfaceSynchronizationCapability: Equatable, Sendable {
    case implicitOnly
    case explicitAvailable(version: RawVersion)
    case explicitActive
}

package enum SurfacePacingCapability: Equatable, Sendable {
    case unavailable
    case fifo(version: RawVersion)
    case commitTiming(version: RawVersion)
    case fifoAndCommitTiming(fifo: RawVersion, commitTiming: RawVersion)

    package var supportsFifo: Bool {
        switch self {
        case .fifo, .fifoAndCommitTiming:
            true
        case .unavailable, .commitTiming:
            false
        }
    }

    package var supportsCommitTiming: Bool {
        switch self {
        case .commitTiming, .fifoAndCommitTiming:
            true
        case .unavailable, .fifo:
            false
        }
    }
}

package struct SurfaceColorRepresentationSupport: Equatable, Sendable {
    package let alphaModes: Set<SurfaceAlphaMode>
    package let coefficientsAndRanges: Set<SurfaceMatrixCoefficientsAndRange>

    package init(
        alphaModes supportedAlphaModes: Set<SurfaceAlphaMode> = [],
        coefficientsAndRanges supportedCoefficientsAndRanges:
            Set<SurfaceMatrixCoefficientsAndRange> = []
    ) {
        alphaModes = supportedAlphaModes
        coefficientsAndRanges = supportedCoefficientsAndRanges
    }
}

package enum SurfaceColorRepresentationCapability: Equatable, Sendable {
    case unavailable
    case pending(version: RawVersion)
    case available(
        version: RawVersion,
        support: SurfaceColorRepresentationSupport
    )

    package var isAvailable: Bool {
        switch self {
        case .unavailable, .pending:
            false
        case .available:
            true
        }
    }
}

package enum SurfaceColorCapability: Equatable, Sendable {
    case unavailable
    case available(version: RawVersion)
    case preferredDescription(SurfaceColorDescriptionReference)

    package var isAvailable: Bool {
        switch self {
        case .unavailable:
            false
        case .available, .preferredDescription:
            true
        }
    }
}

package struct SurfaceCapabilitySnapshot: Equatable, Sendable {
    package let role: SurfaceRuntimeRole
    package let outputIDs: [OutputID]
    package let fractionalScale: SurfaceScaleCapability
    package let presentationFeedback: SurfaceCapabilityStatus
    package let dmabuf: SurfaceDmabufCapability
    package let synchronization: SurfaceSynchronizationCapability
    package let pacing: SurfacePacingCapability
    package let contentType: SurfaceCapabilityStatus
    package let alphaModifier: SurfaceCapabilityStatus
    package let tearingControl: SurfaceCapabilityStatus
    package let colorRepresentation: SurfaceColorRepresentationCapability
    package let color: SurfaceColorCapability

    package init(
        role surfaceRole: SurfaceRuntimeRole,
        outputIDs surfaceOutputIDs: [OutputID],
        fractionalScale surfaceFractionalScale: SurfaceScaleCapability,
        presentationFeedback surfacePresentationFeedback: SurfaceCapabilityStatus,
        dmabuf surfaceDmabuf: SurfaceDmabufCapability,
        synchronization surfaceSynchronization: SurfaceSynchronizationCapability,
        pacing surfacePacing: SurfacePacingCapability,
        contentType surfaceContentType: SurfaceCapabilityStatus = .unavailable,
        alphaModifier surfaceAlphaModifier: SurfaceCapabilityStatus = .unavailable,
        tearingControl surfaceTearingControl: SurfaceCapabilityStatus = .unavailable,
        colorRepresentation surfaceColorRepresentation:
            SurfaceColorRepresentationCapability = .unavailable,
        color surfaceColor: SurfaceColorCapability = .unavailable
    ) {
        role = surfaceRole
        outputIDs = surfaceOutputIDs
        fractionalScale = surfaceFractionalScale
        presentationFeedback = surfacePresentationFeedback
        dmabuf = surfaceDmabuf
        synchronization = surfaceSynchronization
        pacing = surfacePacing
        contentType = surfaceContentType
        alphaModifier = surfaceAlphaModifier
        tearingControl = surfaceTearingControl
        colorRepresentation = surfaceColorRepresentation
        color = surfaceColor
    }
}

struct SurfaceRuntime<RoleResources> {
    struct SurfaceObjects {
        var buffers: RawSharedMemoryPool?
        var retiredBufferPools: [RawSharedMemoryPool] = []
        var scaleInstallation = SurfaceScaleInstallation()
        var outputMembership = SurfaceOutputMembershipState()
        var transactionState = SurfaceTransactionState()
        var submitConstraintObjects = SurfaceSubmitConstraintObjects()
        var metadataObjects = SurfaceMetadataObjects()
    }

    enum Phase {
        case unassigned(SurfaceObjects)
        case live(roleResources: RoleResources, SurfaceObjects)
        case roleDestroyed(SurfaceObjects)
        case surfaceDestroyed(retiredBufferPools: [RawSharedMemoryPool])
    }

    private let role: SurfaceRuntimeRole
    private let surfaceID: RawObjectID?
    private var presentationFeedbackCapability = SurfaceCapabilityStatus.unavailable
    private var dmabufCapability = SurfaceDmabufCapability.unavailable
    var synchronizationCapability = SurfaceSynchronizationCapability.implicitOnly
    var pacingCapability = SurfacePacingCapability.unavailable
    var contentTypeCapability = SurfaceCapabilityStatus.unavailable
    var alphaModifierCapability = SurfaceCapabilityStatus.unavailable
    var tearingControlCapability = SurfaceCapabilityStatus.unavailable
    var colorRepresentationCapability = SurfaceColorRepresentationCapability.unavailable
    var colorCapability = SurfaceColorCapability.unavailable
    var phase: Phase = .unassigned(SurfaceObjects())

    init(role surfaceRole: SurfaceRuntimeRole, surfaceID runtimeSurfaceID: RawObjectID? = nil) {
        role = surfaceRole
        surfaceID = runtimeSurfaceID
    }
}

extension SurfaceRuntime {
    var roleResources: RoleResources? {
        get {
            guard case .live(let roleResources, _) = phase else {
                return nil
            }

            return roleResources
        }
        set {
            replaceLiveRoleResources(with: newValue)
        }
    }

    var buffers: RawSharedMemoryPool? {
        get {
            switch phase {
            case .unassigned(let objects),
                .live(_, let objects),
                .roleDestroyed(let objects):
                objects.buffers
            case .surfaceDestroyed:
                nil
            }
        }
        set {
            guard !isSurfaceDestroyed else {
                return
            }

            updateSurfaceObjects { objects in
                objects.buffers = newValue
            }
        }
    }

    var retiredBufferPools: [RawSharedMemoryPool] {
        get {
            switch phase {
            case .unassigned(let objects),
                .live(_, let objects),
                .roleDestroyed(let objects):
                objects.retiredBufferPools
            case .surfaceDestroyed(let retiredBufferPools):
                retiredBufferPools
            }
        }
        set {
            switch phase {
            case .surfaceDestroyed:
                phase = .surfaceDestroyed(retiredBufferPools: newValue)
            default:
                updateSurfaceObjects { objects in
                    objects.retiredBufferPools = newValue
                }
            }
        }
    }

    var scaleInstallation: SurfaceScaleInstallation {
        get {
            switch phase {
            case .unassigned(let objects),
                .live(_, let objects),
                .roleDestroyed(let objects):
                objects.scaleInstallation
            case .surfaceDestroyed:
                SurfaceScaleInstallation()
            }
        }
        set {
            updateSurfaceObjects { objects in
                objects.scaleInstallation = newValue
            }
        }
    }

    var surfaceRole: SurfaceRuntimeRole {
        role
    }

    mutating func setPresentationFeedbackCapability(
        _ capability: SurfaceCapabilityStatus
    ) {
        presentationFeedbackCapability = capability
    }

    mutating func setDmabufAdvertisement(_ advertisement: SurfaceDmabufAdvertisement) {
        switch advertisement {
        case .unavailable:
            dmabufCapability = .unavailable
        case .advertised(let version, let canRequestSurfaceFeedback):
            dmabufCapability = .advertised(
                version: version,
                canRequestSurfaceFeedback: canRequestSurfaceFeedback
            )
        }
    }

    mutating func setSurfaceDmabufFeedback(
        _ snapshot: RawLinuxDmabufFeedbackSnapshot
    ) throws(SurfaceDmabufCapabilityError) {
        guard let surfaceID else {
            throw SurfaceDmabufCapabilityError.missingSurfaceIdentity
        }

        let dmabufVersion: RawVersion =
            switch dmabufCapability {
            case .advertised(let version, _),
                .surfaceFeedback(let version, feedback: _):
                version
            case .unavailable:
                RawLinuxDmabuf.feedbackRequestMinimumVersion
            }

        dmabufCapability = .surfaceFeedback(
            version: dmabufVersion,
            feedback: try SurfaceDmabufFeedback(snapshot: snapshot, surfaceID: surfaceID)
        )
    }

    mutating func enterOutput(_ outputID: RawOutputID) -> Bool {
        mutateSurfaceObjects(default: false) { objects in
            objects.outputMembership.enter(outputID)
        }
    }

    mutating func leaveOutput(_ outputID: RawOutputID) -> Bool {
        mutateSurfaceObjects(default: false) { objects in
            objects.outputMembership.leave(outputID)
        }
    }

    mutating func removeOutput(_ outputID: OutputID) -> Bool {
        mutateSurfaceObjects(default: false) { objects in
            objects.outputMembership.remove(outputID)
        }
    }

    func currentOutputIDs(
        where isStillBound: (RawOutputID) -> Bool = { _ in true }
    ) -> [OutputID] {
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            objects.outputMembership.currentOutputIDs(where: isStillBound)
        case .surfaceDestroyed:
            []
        }
    }

    func capabilitySnapshot(
        where isStillBound: (RawOutputID) -> Bool = { _ in true }
    ) -> SurfaceCapabilitySnapshot {
        let scaleCapability: SurfaceScaleCapability
        let outputIDs: [OutputID]
        let presentationFeedback: SurfaceCapabilityStatus
        let dmabuf: SurfaceDmabufCapability
        let synchronization: SurfaceSynchronizationCapability
        let pacing: SurfacePacingCapability
        let contentType: SurfaceCapabilityStatus
        let alphaModifier: SurfaceCapabilityStatus
        let tearingControl: SurfaceCapabilityStatus
        let colorRepresentation: SurfaceColorRepresentationCapability
        let color: SurfaceColorCapability

        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            scaleCapability = objects.scaleInstallation.capability
            outputIDs = objects.outputMembership.currentOutputIDs(where: isStillBound)
            presentationFeedback = presentationFeedbackCapability
            dmabuf = dmabufCapability
            synchronization = synchronizationCapability
            pacing = pacingCapability
            contentType = contentTypeCapability
            alphaModifier = alphaModifierCapability
            tearingControl = tearingControlCapability
            colorRepresentation = colorRepresentationCapability
            color = colorCapability
        case .surfaceDestroyed:
            scaleCapability = .integerOnly
            outputIDs = []
            presentationFeedback = .unavailable
            dmabuf = .unavailable
            synchronization = .implicitOnly
            pacing = .unavailable
            contentType = .unavailable
            alphaModifier = .unavailable
            tearingControl = .unavailable
            colorRepresentation = .unavailable
            color = .unavailable
        }

        return SurfaceCapabilitySnapshot(
            role: role,
            outputIDs: outputIDs,
            fractionalScale: scaleCapability,
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

    var transactionSnapshot: SurfaceTransactionSnapshot {
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            objects.transactionState.snapshot
        case .surfaceDestroyed:
            SurfaceTransactionState().snapshot
        }
    }

    mutating func recordConfigureReceived(serial: UInt32) {
        updateSurfaceObjects { objects in
            objects.transactionState.recordConfigureReceived(serial: serial)
        }
    }

    mutating func acknowledgeConfigure(serial: UInt32) throws {
        try updateSurfaceObjects { objects in
            try objects.transactionState.acknowledgeConfigure(serial: serial)
        }
    }

    mutating func requestFrameCallback(generation: UInt64) throws {
        try updateSurfaceObjects { objects in
            try objects.transactionState.requestFrameCallback(generation: generation)
        }
    }

    mutating func cancelFrameCallback() {
        updateSurfaceObjects { objects in
            objects.transactionState.cancelFrameCallback()
        }
    }

    var nextCommitGeneration: UInt64 {
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            objects.transactionState.nextCommitGeneration
        case .surfaceDestroyed:
            SurfaceTransactionState().nextCommitGeneration
        }
    }

    @discardableResult
    mutating func completeFrameCallback() throws -> UInt64? {
        try mutateSurfaceObjects(default: nil) { objects in
            try objects.transactionState.completeFrameCallback()
        }
    }

    mutating func recordCommittedFrame(
        generation: UInt64,
        plan: SurfaceCommitPlan
    ) throws {
        try updateSurfaceObjects { objects in
            try objects.transactionState.recordCommittedFrame(
                generation: generation,
                plan: plan
            )
        }
    }

    func validateCommittedFrameCandidate(
        generation: UInt64
    ) throws {
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            try objects.transactionState.validateCommittedFrameCandidate(
                generation: generation
            )
        case .surfaceDestroyed:
            try SurfaceTransactionState().validateCommittedFrameCandidate(
                generation: generation
            )
        }
    }

    mutating func prepareCommittedFrame(
        generation: UInt64,
        plan: SurfaceCommitPlan
    ) throws {
        try recordCommittedFrame(generation: generation, plan: plan)
    }

    mutating func resetTransientTransactionState() {
        updateSurfaceObjects { objects in
            objects.transactionState.resetTransientState()
        }
    }

    mutating func installRoleResources(_ roleResources: RoleResources) throws {
        switch phase {
        case .unassigned(let objects):
            phase = .live(roleResources: roleResources, objects)
        case .live:
            throw SurfaceRuntimeError.roleResourcesAlreadyInstalled(role: role)
        case .roleDestroyed:
            throw SurfaceRuntimeError.installAfterRoleDestroyed(role: role)
        case .surfaceDestroyed:
            throw SurfaceRuntimeError.installAfterSurfaceDestroyed
        }
    }

    mutating func removeRoleResources() -> RoleResources? {
        guard case .live(let roleResources, let objects) = phase else {
            return nil
        }

        phase = .roleDestroyed(objects)
        return roleResources
    }

    mutating func destroyScaleInstallation() {
        updateSurfaceObjects { objects in
            objects.scaleInstallation.destroy()
        }
    }

    mutating func updateScaleInstallation(
        _ update: (inout SurfaceScaleInstallation) throws -> Bool
    ) rethrows -> Bool {
        switch phase {
        case .unassigned(var objects):
            let result = try update(&objects.scaleInstallation)
            phase = .unassigned(objects)
            return result
        case .live(let roleResources, var objects):
            let result = try update(&objects.scaleInstallation)
            phase = .live(roleResources: roleResources, objects)
            return result
        case .roleDestroyed(var objects):
            let result = try update(&objects.scaleInstallation)
            phase = .roleDestroyed(objects)
            return result
        case .surfaceDestroyed:
            return false
        }
    }

    mutating func markSurfaceDestroyed() throws {
        switch phase {
        case .unassigned(var objects),
            .roleDestroyed(var objects):
            guard objects.buffers == nil else {
                throw SurfaceRuntimeError.surfaceDestroyedWithActiveBufferPool
            }
            objects.submitConstraintObjects.destroy()
            objects.metadataObjects.destroy()
            objects.scaleInstallation.destroy()
            synchronizationCapability = .implicitOnly
            pacingCapability = .unavailable
            contentTypeCapability = .unavailable
            alphaModifierCapability = .unavailable
            tearingControlCapability = .unavailable
            colorRepresentationCapability = .unavailable
            colorCapability = .unavailable
            phase = .surfaceDestroyed(retiredBufferPools: objects.retiredBufferPools)
        case .live:
            throw SurfaceRuntimeError.surfaceDestroyedWithLiveRoleResources
        case .surfaceDestroyed:
            return
        }
    }

    private var isSurfaceDestroyed: Bool {
        guard case .surfaceDestroyed = phase else {
            return false
        }

        return true
    }

    private mutating func replaceLiveRoleResources(with roleResources: RoleResources?) {
        switch (phase, roleResources) {
        case (.live(_, let objects), .some(let roleResources)):
            phase = .live(roleResources: roleResources, objects)
        case (.live(_, let objects), nil):
            phase = .roleDestroyed(objects)
        case (.unassigned, nil),
            (.roleDestroyed, nil),
            (.surfaceDestroyed, nil):
            return
        case (.unassigned, .some),
            (.roleDestroyed, .some),
            (.surfaceDestroyed, .some):
            return
        }
    }

    mutating func updateSurfaceObjects(
        _ update: (inout SurfaceObjects) throws -> Void
    ) rethrows {
        switch phase {
        case .unassigned(var objects):
            try update(&objects)
            phase = .unassigned(objects)
        case .live(let roleResources, var objects):
            try update(&objects)
            phase = .live(roleResources: roleResources, objects)
        case .roleDestroyed(var objects):
            try update(&objects)
            phase = .roleDestroyed(objects)
        case .surfaceDestroyed:
            return
        }
    }

    mutating func mutateSurfaceObjects<Result>(
        default defaultResult: Result,
        _ update: (inout SurfaceObjects) throws -> Result
    ) rethrows -> Result {
        switch phase {
        case .unassigned(var objects):
            let result = try update(&objects)
            phase = .unassigned(objects)
            return result
        case .live(let roleResources, var objects):
            let result = try update(&objects)
            phase = .live(roleResources: roleResources, objects)
            return result
        case .roleDestroyed(var objects):
            let result = try update(&objects)
            phase = .roleDestroyed(objects)
            return result
        case .surfaceDestroyed:
            return defaultResult
        }
    }
}
