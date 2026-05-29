import CWaylandClientSystem
import CWaylandProtocols

@safe
package final class RawSubcompositor {
    @safe let pointer: OpaquePointer
    package let version: RawVersion

    private var proxy: RawOwnedProxy

    @safe
    init(
        pointer subcompositorPointer: OpaquePointer,
        version subcompositorVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = subcompositorVersion
        proxy = try RawOwnedProxy(
            adopting: subcompositorPointer,
            interface: "wl_subcompositor",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_subcompositor_destroy
        )
        pointer = proxy.pointer
    }

    package func getSubsurface(
        surface childSurface: RawSurface,
        parent parentSurface: RawSurface
    ) throws -> RawSubsurface {
        guard
            let subsurface = unsafe swl_subcompositor_get_subsurface(
                pointer,
                childSurface.pointer,
                parentSurface.pointer
            )
        else {
            throw RuntimeError.bindFailed("wl_subsurface")
        }

        return RawSubsurface(pointer: subsurface)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawSubsurface {
    private var proxy: RawOwnedProxy

    @safe var pointer: OpaquePointer {
        proxy.pointer
    }

    @safe
    init(pointer subsurfacePointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: subsurfacePointer,
            destroy: unsafe swl_subsurface_destroy
        )
    }

    package func setPosition(x: Int32, y: Int32) {
        unsafe swl_subsurface_set_position(pointer, x, y)
    }

    package func placeAbove(_ sibling: RawSurface) {
        unsafe swl_subsurface_place_above(pointer, sibling.pointer)
    }

    package func placeBelow(_ sibling: RawSurface) {
        unsafe swl_subsurface_place_below(pointer, sibling.pointer)
    }

    package func setSynchronized() {
        unsafe swl_subsurface_set_sync(pointer)
    }

    package func setDesynchronized() {
        unsafe swl_subsurface_set_desync(pointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
