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
    case subsurface
}

package struct SurfaceRoleReadinessSnapshot: Equatable, Sendable {
    package let role: SurfaceRuntimeRole
    package let hasRuntime: Bool
    package let hasRoleResources: Bool
    package let acceptsDamage: Bool
    package let acceptsInputRegion: Bool
    package let acceptsOpaqueRegion: Bool
    package let acceptsMetadata: Bool
    package let acceptsSubmitConstraints: Bool
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

    private enum RolePhase {
        case unassigned
        case live(RoleResources)
        case destroyed
    }

    private struct Alive {
        var rolePhase = RolePhase.unassigned
        var objects = SurfaceObjects()
    }

    private enum Storage {
        case alive(Alive)
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
    private var storage = Storage.alive(Alive())

    init(role surfaceRole: SurfaceRuntimeRole, surfaceID runtimeSurfaceID: RawObjectID? = nil) {
        role = surfaceRole
        surfaceID = runtimeSurfaceID
    }
}

extension SurfaceRuntime {
    var roleResources: RoleResources? {
        get {
            guard case .alive(let alive) = storage,
                case .live(let roleResources) = alive.rolePhase
            else {
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
            surfaceObjects?.buffers
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
            switch storage {
            case .alive(let alive):
                alive.objects.retiredBufferPools
            case .surfaceDestroyed(let retiredBufferPools):
                retiredBufferPools
            }
        }
        set {
            switch storage {
            case .surfaceDestroyed:
                storage = .surfaceDestroyed(retiredBufferPools: newValue)
            case .alive(var alive):
                alive.objects.retiredBufferPools = newValue
                storage = .alive(alive)
            }
        }
    }

    var scaleInstallation: SurfaceScaleInstallation {
        get {
            surfaceObjects?.scaleInstallation ?? SurfaceScaleInstallation()
        }
        set {
            updateSurfaceObjects { objects in
                objects.scaleInstallation = newValue
            }
        }
    }

    var roleReadinessSnapshot: SurfaceRoleReadinessSnapshot {
        let hasRuntime: Bool
        let hasRoleResources: Bool
        switch storage {
        case .alive(let alive):
            hasRuntime = true
            if case .live = alive.rolePhase {
                hasRoleResources = true
            } else {
                hasRoleResources = false
            }
        case .surfaceDestroyed:
            hasRuntime = false
            hasRoleResources = false
        }

        return SurfaceRoleReadinessSnapshot(
            role: role,
            hasRuntime: hasRuntime,
            hasRoleResources: hasRoleResources,
            acceptsDamage: role.acceptsManagedDamage,
            acceptsInputRegion: role.acceptsSurfaceRegions,
            acceptsOpaqueRegion: role.acceptsSurfaceRegions,
            acceptsMetadata: role.acceptsCommitMetadata,
            acceptsSubmitConstraints: role.acceptsSubmitConstraints
        )
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
        guard let objects = surfaceObjects else { return [] }
        return objects.outputMembership.currentOutputIDs(where: isStillBound)
    }

    func capabilitySnapshot(
        where isStillBound: (RawOutputID) -> Bool = { _ in true }
    ) -> SurfaceCapabilitySnapshot {
        guard let objects = surfaceObjects else {
            return destroyedCapabilitySnapshot()
        }

        return SurfaceCapabilitySnapshot(
            role: role,
            outputIDs: objects.outputMembership.currentOutputIDs(where: isStillBound),
            fractionalScale: objects.scaleInstallation.capability,
            presentationFeedback: presentationFeedbackCapability,
            dmabuf: dmabufCapability,
            synchronization: synchronizationCapability,
            pacing: pacingCapability,
            contentType: contentTypeCapability,
            alphaModifier: alphaModifierCapability,
            tearingControl: tearingControlCapability,
            colorRepresentation: colorRepresentationCapability,
            color: colorCapability
        )
    }

    var transactionSnapshot: SurfaceTransactionSnapshot {
        surfaceObjects?.transactionState.snapshot ?? SurfaceTransactionState().snapshot
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

    mutating func markConfigureIndependentRoleReady() {
        updateSurfaceObjects { objects in
            objects.transactionState.markConfigureIndependentRoleReady()
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
        surfaceObjects?.transactionState.nextCommitGeneration
            ?? SurfaceTransactionState().nextCommitGeneration
    }

    @discardableResult
    mutating func completeFrameCallback() throws -> UInt64? {
        try mutateSurfaceObjects(default: nil) { objects in
            try objects.transactionState.completeFrameCallback()
        }
    }

    mutating func recordCommittedFrame(
        generation: UInt64,
        plan: SurfaceCommitPlan,
        payload: SurfaceCommittedPayload = .buffer
    ) throws {
        try updateSurfaceObjects { objects in
            try objects.transactionState.recordCommittedFrame(
                generation: generation,
                plan: plan,
                payload: payload
            )
        }
    }

    func validateCommittedFrameCandidate(
        generation: UInt64
    ) throws {
        let transactionState = surfaceObjects?.transactionState ?? SurfaceTransactionState()
        try transactionState.validateCommittedFrameCandidate(generation: generation)
    }

    mutating func prepareCommittedFrame(
        generation: UInt64,
        plan: SurfaceCommitPlan,
        payload: SurfaceCommittedPayload = .buffer
    ) throws {
        try recordCommittedFrame(generation: generation, plan: plan, payload: payload)
    }

    mutating func resetTransientTransactionState() {
        updateSurfaceObjects { objects in
            objects.transactionState.resetTransientState()
        }
    }

    mutating func installRoleResources(_ roleResources: RoleResources) throws {
        switch storage {
        case .alive(var alive):
            switch alive.rolePhase {
            case .unassigned:
                alive.rolePhase = .live(roleResources)
                storage = .alive(alive)
            case .live:
                throw SurfaceRuntimeError.roleResourcesAlreadyInstalled(role: role)
            case .destroyed:
                throw SurfaceRuntimeError.installAfterRoleDestroyed(role: role)
            }
        case .surfaceDestroyed:
            throw SurfaceRuntimeError.installAfterSurfaceDestroyed
        }
    }

    mutating func removeRoleResources() -> RoleResources? {
        guard case .alive(var alive) = storage,
            case .live(let roleResources) = alive.rolePhase
        else {
            return nil
        }

        alive.rolePhase = .destroyed
        storage = .alive(alive)
        return roleResources
    }

    mutating func destroyScaleInstallation() {
        updateSurfaceObjects { objects in
            objects.scaleInstallation.destroy()
        }
    }

    mutating func updateScaleInstallation<Failure: Error>(
        _ update: (inout SurfaceScaleInstallation) throws(Failure) -> Bool
    ) throws(Failure) -> Bool {
        try mutateSurfaceObjects(default: false) { objects throws(Failure) in
            try update(&objects.scaleInstallation)
        }
    }

    mutating func markSurfaceDestroyed() throws {
        switch storage {
        case .alive(var alive):
            if case .live = alive.rolePhase {
                throw SurfaceRuntimeError.surfaceDestroyedWithLiveRoleResources
            }
            guard alive.objects.buffers == nil else {
                throw SurfaceRuntimeError.surfaceDestroyedWithActiveBufferPool
            }
            alive.objects.submitConstraintObjects.destroy()
            alive.objects.metadataObjects.destroy()
            alive.objects.scaleInstallation.destroy()
            resetCapabilitiesAfterSurfaceDestruction()
            storage = .surfaceDestroyed(
                retiredBufferPools: alive.objects.retiredBufferPools
            )
        case .surfaceDestroyed:
            return
        }
    }

    /// Returns the live surface-owned objects, or `nil` after surface destruction.
    var surfaceObjects: SurfaceObjects? {
        guard case .alive(let alive) = storage else { return nil }
        return alive.objects
    }

    private var isSurfaceDestroyed: Bool {
        guard case .surfaceDestroyed = storage else {
            return false
        }

        return true
    }

    private func destroyedCapabilitySnapshot() -> SurfaceCapabilitySnapshot {
        SurfaceCapabilitySnapshot(
            role: role,
            outputIDs: [],
            fractionalScale: .integerOnly,
            presentationFeedback: .unavailable,
            dmabuf: .unavailable,
            synchronization: .implicitOnly,
            pacing: .unavailable,
            contentType: .unavailable,
            alphaModifier: .unavailable,
            tearingControl: .unavailable,
            colorRepresentation: .unavailable,
            color: .unavailable
        )
    }

    private mutating func resetCapabilitiesAfterSurfaceDestruction() {
        synchronizationCapability = .implicitOnly
        pacingCapability = .unavailable
        contentTypeCapability = .unavailable
        alphaModifierCapability = .unavailable
        tearingControlCapability = .unavailable
        colorRepresentationCapability = .unavailable
        colorCapability = .unavailable
    }

    private mutating func replaceLiveRoleResources(with roleResources: RoleResources?) {
        guard case .alive(var alive) = storage else { return }

        switch (alive.rolePhase, roleResources) {
        case (.live, .some(let roleResources)):
            alive.rolePhase = .live(roleResources)
        case (.live, nil):
            alive.rolePhase = .destroyed
        case (.unassigned, _), (.destroyed, _):
            return
        }
        storage = .alive(alive)
    }

    /// Updates live surface objects and commits the changes only when the body succeeds.
    mutating func updateSurfaceObjects<Failure: Error>(
        _ update: (inout SurfaceObjects) throws(Failure) -> Void
    ) throws(Failure) {
        guard case .alive(var alive) = storage else { return }
        try update(&alive.objects)
        storage = .alive(alive)
    }

    /// Updates live surface objects and returns a default after surface destruction.
    ///
    /// Changes made by a throwing body are discarded because storage is written back
    /// only after the body returns successfully.
    mutating func mutateSurfaceObjects<Result, Failure: Error>(
        default defaultResult: Result,
        _ update: (inout SurfaceObjects) throws(Failure) -> Result
    ) throws(Failure) -> Result {
        guard case .alive(var alive) = storage else { return defaultResult }
        let result = try update(&alive.objects)
        storage = .alive(alive)
        return result
    }
}

extension SurfaceRuntimeRole {
    private var isManagedPresentableSurface: Bool {
        switch self {
        case .toplevelWindow, .popup, .subsurface:
            true
        case .cursor, .dragIcon:
            false
        }
    }

    var acceptsManagedDamage: Bool {
        isManagedPresentableSurface
    }

    var acceptsSurfaceRegions: Bool {
        isManagedPresentableSurface
    }

    var acceptsCommitMetadata: Bool {
        isManagedPresentableSurface
    }

    var acceptsSubmitConstraints: Bool {
        isManagedPresentableSurface
    }
}
