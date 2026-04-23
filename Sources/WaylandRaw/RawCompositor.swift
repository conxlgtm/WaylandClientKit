import CWaylandClientSystem
import CWaylandProtocols

public final class RawCompositor {
    public let pointer: OpaquePointer
    public let version: RawVersion

    public init(pointer compositorPointer: OpaquePointer, version compositorVersion: RawVersion) {
        pointer = compositorPointer
        version = compositorVersion
    }

    public func createSurface() throws -> RawSurface {
        guard let surface = swl_compositor_create_surface(pointer) else {
            throw RuntimeError.bindFailed("wl_surface")
        }

        return RawSurface(pointer: surface, version: version)
    }
}
