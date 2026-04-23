import CWaylandClientSystem
import CWaylandProtocols

public final class RawSurface {
    public let pointer: OpaquePointer
    public let version: RawVersion

    private var isDestroyed = false

    public init(pointer surfacePointer: OpaquePointer, version surfaceVersion: RawVersion) {
        pointer = surfacePointer
        version = surfaceVersion
    }

    public func damageFullBuffer(width: Int32, height: Int32) {
        if usesBufferDamage {
            swl_surface_damage_buffer(pointer, 0, 0, width, height)
        } else {
            swl_surface_damage(pointer, 0, 0, width, height)
        }
    }

    public var usesBufferDamage: Bool {
        version >= 4
    }

    public func commit() {
        swl_surface_commit(pointer)
    }

    public func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        swl_surface_destroy(pointer)
    }

    deinit {
        destroy()
    }
}
