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

public final class RawXDGWMBase {
    public let pointer: OpaquePointer
    public let version: RawVersion

    public init(pointer wmBasePointer: OpaquePointer, version wmBaseVersion: RawVersion) {
        pointer = wmBasePointer
        version = wmBaseVersion
    }

    public func getSurface(for surface: RawSurface) throws -> RawXDGSurface {
        guard
            let surfacePointer = swl_xdg_wm_base_get_xdg_surface(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("xdg_surface")
        }

        return .init(pointer: surfacePointer, version: version)
    }
}

public final class XDGWMBaseOwner {
    private let wmBase: OpaquePointer
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_xdg_wm_base_listener_callbacks>

    public init(wmBase pointer: OpaquePointer) {
        wmBase = pointer
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: swl_xdg_wm_base_listener_callbacks())

        callbacks.pointee.ping = { data, wmBase, serial in
            guard data != nil, let wmBase else { return }

            // We must pong, otherwise the compositor can treat the app as hung
            swl_xdg_wm_base_pong(wmBase, serial)
        }
    }

    public func install() throws {
        callbacks.pointee.data = callbackStorage.opaquePointer

        let result = swl_xdg_wm_base_add_listener(wmBase, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }
    }

    deinit {
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}

public final class XDGSurfaceOwner {
    private let configureState: XDGConfigureState
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_xdg_surface_listener_callbacks>

    public init(configureState state: XDGConfigureState) {
        configureState = state
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: swl_xdg_surface_listener_callbacks())

        callbacks.pointee.configure = { data, _, serial in
            guard let data else { return }

            let owner = CallbackBox<XDGSurfaceOwner>.fromOpaque(data).owner
            owner?.configureState.handleSurfaceConfigure(serial: serial)
        }
    }

    public func install(on xdgSurface: RawXDGSurface) throws {
        callbacks.pointee.data = callbackStorage.opaquePointer

        let result = swl_xdg_surface_add_listener(xdgSurface.pointer, callbacks)

        guard result == 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }
    }

    deinit {
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}

public final class XDGTopLevelOwner {
    private let configureState: XDGConfigureState
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_xdg_toplevel_listener_callbacks>
    private var onClose: (() -> Void)?

    public init(configureState state: XDGConfigureState) {
        configureState = state
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: swl_xdg_toplevel_listener_callbacks())

        callbacks.pointee.configure = { data, _, width, height, _ in
            guard let data else {
                return
            }

            let owner = CallbackBox<XDGTopLevelOwner>.fromOpaque(data).owner
            owner?.configureState.handleTopLevelConfigure(
                width: width,
                height: height
            )
        }

        callbacks.pointee.close = { data, _ in
            guard let data else {
                return
            }

            let owner = CallbackBox<XDGTopLevelOwner>.fromOpaque(data).owner
            owner?.onClose?()
        }
    }

    public func install(
        on topLevel: RawXDGTopLevel,
        onClose closeHandler: @escaping () -> Void
    ) throws {
        onClose = closeHandler
        callbacks.pointee.data = callbackStorage.opaquePointer

        let result = swl_xdg_toplevel_add_listener(
            topLevel.pointer,
            callbacks
        )

        guard result == 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }
    }

    deinit {
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}
