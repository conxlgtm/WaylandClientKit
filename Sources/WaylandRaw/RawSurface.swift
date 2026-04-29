import CWaylandClientSystem
import CWaylandProtocols

public final class RawSurface {
    let pointer: OpaquePointer
    public let version: RawVersion

    private var isDestroyed = false

    init(pointer surfacePointer: OpaquePointer, version surfaceVersion: RawVersion) {
        pointer = surfacePointer
        version = surfaceVersion
    }

    public func requestFrame(onDone handler: @escaping () -> Void) throws
        -> FrameCallbackRegistration
    {
        guard let callback = swl_surface_frame(pointer) else {
            throw RuntimeError.frameRequestFailed
        }

        return try .init(pointer: callback, onDone: handler)
    }

    public func attach(buffer: RawBuffer?, x: Int32 = 0, y: Int32 = 0) {
        swl_surface_attach(pointer, buffer?.pointer, x, y)
    }

    package func attachBorrowedBuffer(
        _ buffer: RawBorrowedBuffer?,
        x: Int32 = 0,
        y: Int32 = 0
    ) {
        swl_surface_attach(pointer, buffer?.pointer, x, y)
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

    package var objectID: RawObjectID {
        RawObjectID(swl_proxy_get_id(UnsafeMutableRawPointer(pointer)))
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
