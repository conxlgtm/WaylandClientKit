import WaylandCursor
import WaylandRaw

package struct CursorRoleResources: Equatable, Sendable {}

package struct CursorRoleRuntime {
    private var runtime: SurfaceRuntime<CursorRoleResources>

    package init(surfaceID: RawObjectID?) throws {
        runtime = SurfaceRuntime(role: .cursor, surfaceID: surfaceID)
        try runtime.installRoleResources(CursorRoleResources())
    }

    package var capabilitySnapshot: SurfaceCapabilitySnapshot {
        runtime.capabilitySnapshot()
    }

    package var transactionSnapshot: SurfaceTransactionSnapshot {
        runtime.transactionSnapshot
    }

    package mutating func destroy() throws {
        _ = runtime.removeRoleResources()
        try runtime.markSurfaceDestroyed()
    }
}

package final class CursorRoleSurface: CursorManagerSurface {
    let rawSurface: RawSurface
    private var runtime: CursorRoleRuntime
    private var isDestroyed = false

    init(surface: RawSurface) throws {
        rawSurface = surface
        runtime = try CursorRoleRuntime(surfaceID: surface.objectID)
    }

    package var objectID: RawObjectID? {
        rawSurface.objectID
    }

    package var capabilitySnapshot: SurfaceCapabilitySnapshot {
        runtime.capabilitySnapshot
    }

    package func attach(_ image: CursorImage) {
        rawSurface.attachBorrowedBuffer(image.buffer)
        rawSurface.damageFullBuffer(width: image.width, height: image.height)
    }

    package func detach() {
        rawSurface.attachBorrowedBuffer(nil)
    }

    package func commit() {
        rawSurface.commit()
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        do {
            try runtime.destroy()
        } catch {
            assertionFailure("cursor surface runtime destroy failed: \(error)")
        }
        rawSurface.destroy()
    }
}
