import WaylandRaw

struct SurfaceRuntime<RoleResources> {
    private struct SurfaceObjects {
        var buffers: RawSharedMemoryPool?
        var retiredBufferPools: [RawSharedMemoryPool] = []
        var scaleInstallation = SurfaceScaleInstallation()
    }

    private enum Phase {
        case unassigned(SurfaceObjects)
        case live(roleResources: RoleResources, SurfaceObjects)
        case roleDestroyed(SurfaceObjects)
        case surfaceDestroyed(retiredBufferPools: [RawSharedMemoryPool])
    }

    private var phase: Phase = .unassigned(SurfaceObjects())

    var roleResources: RoleResources? {
        get {
            guard case .live(let roleResources, _) = phase else {
                return nil
            }

            return roleResources
        }
        set {
            replaceRoleResources(with: newValue)
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
            guard newValue != nil || !isSurfaceDestroyed else {
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
                preconditionFailure("Surface scale resources used after surface destruction")
            }
        }
        set {
            updateSurfaceObjects { objects in
                objects.scaleInstallation = newValue
            }
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

    mutating func markSurfaceDestroyed() {
        switch phase {
        case .unassigned(var objects),
            .roleDestroyed(var objects):
            precondition(
                objects.buffers == nil,
                "Surface destroyed with an active buffer pool"
            )
            objects.scaleInstallation.destroy()
            phase = .surfaceDestroyed(retiredBufferPools: objects.retiredBufferPools)
        case .live:
            preconditionFailure("Surface destroyed with live role resources")
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

    private mutating func replaceRoleResources(with roleResources: RoleResources?) {
        switch (phase, roleResources) {
        case (.unassigned(let objects), .some(let roleResources)),
            (.roleDestroyed(let objects), .some(let roleResources)):
            phase = .live(roleResources: roleResources, objects)
        case (.live(_, let objects), .some(let roleResources)):
            phase = .live(roleResources: roleResources, objects)
        case (.live(_, let objects), nil):
            phase = .roleDestroyed(objects)
        case (.unassigned, nil),
            (.roleDestroyed, nil),
            (.surfaceDestroyed, nil):
            return
        case (.surfaceDestroyed, .some):
            preconditionFailure("Role resources installed after surface destruction")
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
            preconditionFailure("Surface resources used after surface destruction")
        }
    }
}
