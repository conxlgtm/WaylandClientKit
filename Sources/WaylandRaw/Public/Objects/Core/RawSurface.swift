import CWaylandClientSystem
import CWaylandProtocols

@safe
package final class RawSurface {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer surfacePointer: OpaquePointer,
        version surfaceVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        let adoptedPointer: OpaquePointer
        do {
            unsafe adoptedPointer = try adoptionContext.adopt(
                surfacePointer,
                interface: "wl_surface"
            )
        } catch {
            unsafe swl_surface_destroy(surfacePointer)
            throw error
        }
        version = surfaceVersion
        proxyAdoption = adoptionContext
        proxy = RawOwnedProxy(
            pointer: adoptedPointer,
            destroy: unsafe swl_surface_destroy
        )
    }

    package func requestFrame(onDone handler: @escaping () -> Void) throws
        -> FrameCallbackRegistration
    {
        guard let callback = unsafe swl_surface_frame(pointer) else {
            throw RuntimeError.frameRequestFailed
        }

        do {
            _ = try proxyAdoption.adopt(callback, interface: "wl_callback")
        } catch {
            unsafe swl_callback_destroy(callback)
            throw error
        }
        return try .init(
            pointer: callback,
            onDone: handler,
            invariantFailureSink: proxyAdoption.invariantFailureSink
        )
    }

    package func attach(buffer: RawBuffer?, x: Int32 = 0, y: Int32 = 0) {
        unsafe swl_surface_attach(pointer, buffer?.pointer, x, y)
    }

    package func attach(buffer: RawSurfaceBuffer?, x: Int32 = 0, y: Int32 = 0) {
        unsafe swl_surface_attach(pointer, buffer?.pointer, x, y)
    }

    package func attachBorrowedBuffer(
        _ buffer: RawBorrowedBuffer?,
        x: Int32 = 0,
        y: Int32 = 0
    ) {
        unsafe swl_surface_attach(pointer, buffer?.pointer, x, y)
    }

    package func damageFullBuffer(width: Int32, height: Int32) {
        if usesBufferDamage {
            unsafe swl_surface_damage_buffer(pointer, 0, 0, width, height)
        } else {
            unsafe swl_surface_damage(pointer, 0, 0, width, height)
        }
    }

    package func damageFullLogical(width: Int32, height: Int32) {
        unsafe swl_surface_damage(pointer, 0, 0, width, height)
    }

    package func setBufferScale(_ scale: Int32) {
        guard version >= 3 else { return }

        unsafe swl_surface_set_buffer_scale(pointer, scale)
    }

    package var usesBufferDamage: Bool {
        version >= 4
    }

    package var objectID: RawObjectID {
        unsafe RawObjectID(swl_proxy_get_id(UnsafeMutableRawPointer(pointer)))
    }

    package func commit() {
        unsafe swl_surface_commit(pointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
