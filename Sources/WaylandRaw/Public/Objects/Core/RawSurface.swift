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
        version = surfaceVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: surfacePointer,
            interface: "wl_surface",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_surface_destroy
        )
    }

    package func requestFrame(onDone handler: @escaping () -> Void) throws
        -> FrameCallbackRegistration
    {
        guard let callback = unsafe swl_surface_frame(pointer) else {
            throw RuntimeError.frameRequestFailed
        }

        let adoptedCallback = try unsafe proxyAdoption.adoptOrDestroy(
            callback,
            interface: "wl_callback",
            destroy: unsafe swl_callback_destroy
        )
        return try .init(
            pointer: adoptedCallback,
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
        damageBuffer(x: 0, y: 0, width: width, height: height)
    }

    package func damageBuffer(x: Int32, y: Int32, width: Int32, height: Int32) {
        if usesBufferDamage {
            unsafe swl_surface_damage_buffer(pointer, x, y, width, height)
        } else {
            unsafe swl_surface_damage(pointer, x, y, width, height)
        }
    }

    package func damageFullLogical(width: Int32, height: Int32) {
        damageLogical(x: 0, y: 0, width: width, height: height)
    }

    package func damageLogical(x: Int32, y: Int32, width: Int32, height: Int32) {
        unsafe swl_surface_damage(pointer, x, y, width, height)
    }

    package func setOpaqueRegion(_ region: RawRegion?) {
        unsafe swl_surface_set_opaque_region(pointer, region?.pointer)
    }

    package func setInputRegion(_ region: RawRegion?) {
        unsafe swl_surface_set_input_region(pointer, region?.pointer)
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

extension RawSurface {
    @safe
    package static func testingSurface(
        pointer surfacePointer: OpaquePointer,
        version surfaceVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) -> RawSurface {
        try RawSurface(
            pointer: surfacePointer,
            version: surfaceVersion,
            proxyAdoption: adoptionContext
        )
    }
}
