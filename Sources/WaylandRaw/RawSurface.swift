import CWaylandClientSystem
import CWaylandProtocols

package final class RawSurface {
    let pointer: OpaquePointer
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var isDestroyed = false

    init(
        pointer surfacePointer: OpaquePointer,
        version surfaceVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            pointer = try adoptionContext.adopt(surfacePointer, interface: "wl_surface")
        } catch {
            swl_surface_destroy(surfacePointer)
            throw error
        }
        version = surfaceVersion
        proxyAdoption = adoptionContext
    }

    package func requestFrame(onDone handler: @escaping () -> Void) throws
        -> FrameCallbackRegistration
    {
        guard let callback = swl_surface_frame(pointer) else {
            throw RuntimeError.frameRequestFailed
        }

        do {
            _ = try proxyAdoption.adopt(callback, interface: "wl_callback")
        } catch {
            swl_callback_destroy(callback)
            throw error
        }
        return try .init(
            pointer: callback,
            onDone: handler,
            invariantFailureSink: proxyAdoption.invariantFailureSink
        )
    }

    package func attach(buffer: RawBuffer?, x: Int32 = 0, y: Int32 = 0) {
        swl_surface_attach(pointer, buffer?.pointer, x, y)
    }

    package func attachBorrowedBuffer(
        _ buffer: RawBorrowedBuffer?,
        x: Int32 = 0,
        y: Int32 = 0
    ) {
        swl_surface_attach(pointer, buffer?.pointer, x, y)
    }

    package func damageFullBuffer(width: Int32, height: Int32) {
        if usesBufferDamage {
            swl_surface_damage_buffer(pointer, 0, 0, width, height)
        } else {
            swl_surface_damage(pointer, 0, 0, width, height)
        }
    }

    package var usesBufferDamage: Bool {
        version >= 4
    }

    package var objectID: RawObjectID {
        RawObjectID(swl_proxy_get_id(UnsafeMutableRawPointer(pointer)))
    }

    package func commit() {
        swl_surface_commit(pointer)
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        swl_surface_destroy(pointer)
    }

    deinit {
        destroy()
    }
}
