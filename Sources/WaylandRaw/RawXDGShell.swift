import CWaylandClientSystem
import CWaylandProtocols
import Glibc

public final class RawXDGTopLevel {
    public let pointer: OpaquePointer
    public let version: RawVersion

    private var isDestroyed = false

    public init(pointer topLevelPointer: OpaquePointer, version topLevelVersion: RawVersion) {
        pointer = topLevelPointer
        version = topLevelVersion
    }

    public func setTitle(_ title: String) {
        title.withCString { titlePointer in
            swl_xdg_toplevel_set_title(pointer, titlePointer)
        }
    }

    public func setAppID(_ appID: String) {
        appID.withCString { appIDPointer in
            swl_xdg_toplevel_set_app_id(pointer, appIDPointer)
        }
    }

    public func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        swl_xdg_toplevel_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

public final class RawXDGSurface {
    public let pointer: OpaquePointer
    public let version: RawVersion

    private var isDestroyed = false

    public init(pointer surfacePointer: OpaquePointer, version surfaceVersion: RawVersion) {
        pointer = surfacePointer
        version = surfaceVersion
    }

    public func getTopLevel() throws -> RawXDGTopLevel {
        guard let pointer = swl_xdg_surface_get_toplevel(pointer) else {
            throw RuntimeError.bindFailed("xdg_toplevel")
        }

        return .init(pointer: pointer, version: version)
    }
}
