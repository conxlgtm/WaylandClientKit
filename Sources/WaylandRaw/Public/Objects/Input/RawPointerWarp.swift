import CWaylandProtocols

@safe
package final class RawPointerWarp {
    package let version: RawVersion

    private var proxy: RawOwnedProxy
    @safe private var pointer: OpaquePointer {
        proxy.pointer
    }

    @safe
    init(
        pointer warpPointer: OpaquePointer,
        version warpVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = warpVersion
        proxy = try RawOwnedProxy(
            adopting: warpPointer,
            interface: "wp_pointer_warp_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_pointer_warp_v1_destroy
        )
    }

    package func warpPointer(
        surface: RawSurface,
        seat: RawSeat,
        x: WaylandFixed,
        y: WaylandFixed,
        serial: UInt32
    ) throws {
        guard let pointerDevice = unsafe seat.pointerDevicePointer else {
            throw RuntimeError.bindFailed("wl_pointer")
        }

        unsafe swl_wp_pointer_warp_v1_warp_pointer(
            pointer,
            surface.pointer,
            pointerDevice,
            x.rawValue,
            y.rawValue,
            serial
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
