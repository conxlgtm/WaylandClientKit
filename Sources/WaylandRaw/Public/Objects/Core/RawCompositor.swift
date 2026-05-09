import CWaylandClientSystem
import CWaylandProtocols

@safe
package final class RawCompositor {
    @safe let pointer: OpaquePointer
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var isDestroyed = false

    @safe
    init(
        pointer compositorPointer: OpaquePointer,
        version compositorVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            pointer = try adoptionContext.adopt(compositorPointer, interface: "wl_compositor")
        } catch {
            unsafe swl_compositor_destroy(compositorPointer)
            throw error
        }
        version = compositorVersion
        proxyAdoption = adoptionContext
    }

    package func createSurface() throws -> RawSurface {
        guard let surface = unsafe swl_compositor_create_surface(pointer) else {
            throw RuntimeError.bindFailed("wl_surface")
        }

        return try RawSurface(pointer: surface, version: version, proxyAdoption: proxyAdoption)
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        unsafe swl_compositor_destroy(pointer)
    }

    deinit {
        destroy()
    }
}
