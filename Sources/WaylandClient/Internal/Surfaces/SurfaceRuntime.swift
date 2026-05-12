import WaylandRaw

extension OptionalPresentation {
    var surfaceCapabilityStatus: SurfaceCapabilityStatus {
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

package struct SurfaceCapabilitySnapshot: Equatable, Sendable {
    package let role: SurfaceRuntimeRole
    package let outputIDs: [OutputID]
    package let fractionalScale: SurfaceScaleCapability
    package let presentationFeedback: SurfaceCapabilityStatus
    package let dmabufFeedback: SurfaceCapabilityStatus
    package let colorMetadata: SurfaceCapabilityStatus
    package let explicitSync: SurfaceCapabilityStatus
}

struct SurfaceRuntime<RoleResources> {
    private struct SurfaceObjects {
        var buffers: RawSharedMemoryPool?
        var retiredBufferPools: [RawSharedMemoryPool] = []
        var scaleInstallation = SurfaceScaleInstallation()
        var outputMembership = SurfaceOutputMembershipState()
    }

    private enum Phase {
        case unassigned(SurfaceObjects)
        case live(roleResources: RoleResources, SurfaceObjects)
        case roleDestroyed(SurfaceObjects)
        case surfaceDestroyed(retiredBufferPools: [RawSharedMemoryPool])
    }

    private let role: SurfaceRuntimeRole
    private var presentationFeedbackCapability = SurfaceCapabilityStatus.unavailable
    private var phase: Phase = .unassigned(SurfaceObjects())

    init(role surfaceRole: SurfaceRuntimeRole) {
        role = surfaceRole
    }

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

        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            scaleCapability = objects.scaleInstallation.capability
            outputIDs = objects.outputMembership.currentOutputIDs(where: isStillBound)
            presentationFeedback = presentationFeedbackCapability
        case .surfaceDestroyed:
            scaleCapability = .integerOnly
            outputIDs = []
            presentationFeedback = .unavailable
        }

        return SurfaceCapabilitySnapshot(
            role: role,
            outputIDs: outputIDs,
            fractionalScale: scaleCapability,
            presentationFeedback: presentationFeedback,
            dmabufFeedback: .unavailable,
            colorMetadata: .unavailable,
            explicitSync: .unavailable
        )
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
            objects.scaleInstallation.destroy()
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

    private mutating func updateSurfaceObjects(
        _ update: (inout SurfaceObjects) -> Void
    ) {
        switch phase {
        case .unassigned(var objects):
            update(&objects)
            phase = .unassigned(objects)
        case .live(let roleResources, var objects):
            update(&objects)
            phase = .live(roleResources: roleResources, objects)
        case .roleDestroyed(var objects):
            update(&objects)
            phase = .roleDestroyed(objects)
        case .surfaceDestroyed:
            return
        }
    }

    private mutating func mutateSurfaceObjects<Result>(
        default defaultResult: Result,
        _ update: (inout SurfaceObjects) -> Result
    ) -> Result {
        switch phase {
        case .unassigned(var objects):
            let result = update(&objects)
            phase = .unassigned(objects)
            return result
        case .live(let roleResources, var objects):
            let result = update(&objects)
            phase = .live(roleResources: roleResources, objects)
            return result
        case .roleDestroyed(var objects):
            let result = update(&objects)
            phase = .roleDestroyed(objects)
            return result
        case .surfaceDestroyed:
            return defaultResult
        }
    }
}
