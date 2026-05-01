import CWaylandClientSystem
import CWaylandProtocols

public final class RawCompositor {
    let pointer: OpaquePointer
    public let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var isDestroyed = false

    init(
        pointer compositorPointer: OpaquePointer,
        version compositorVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            pointer = try adoptionContext.adopt(compositorPointer, interface: "wl_compositor")
        } catch {
            swl_compositor_destroy(compositorPointer)
            throw error
        }
        version = compositorVersion
        proxyAdoption = adoptionContext
    }

    public func createSurface() throws -> RawSurface {
        guard let surface = swl_compositor_create_surface(pointer) else {
            throw RuntimeError.bindFailed("wl_surface")
        }

        return try RawSurface(pointer: surface, version: version, proxyAdoption: proxyAdoption)
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        swl_compositor_destroy(pointer)
    }

    deinit {
        destroy()
    }
}
