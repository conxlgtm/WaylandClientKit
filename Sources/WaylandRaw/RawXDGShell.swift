import CWaylandClientSystem
import CWaylandProtocols
import Glibc

public final class RawXDGTopLevel {
    let pointer: OpaquePointer
    public let version: RawVersion

    private var isDestroyed = false

    init(pointer topLevelPointer: OpaquePointer, version topLevelVersion: RawVersion) {
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
    let pointer: OpaquePointer
    public let version: RawVersion

    private var isDestroyed = false

    init(pointer surfacePointer: OpaquePointer, version surfaceVersion: RawVersion) {
        pointer = surfacePointer
        version = surfaceVersion
    }

    public func getTopLevel() throws -> RawXDGTopLevel {
        guard let pointer = swl_xdg_surface_get_toplevel(pointer) else {
            throw RuntimeError.bindFailed("xdg_toplevel")
        }

        return .init(pointer: pointer, version: version)
    }

    public func ackConfigure(serial: UInt32) {
        swl_xdg_surface_ack_configure(pointer, serial)
    }

    public func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        swl_xdg_surface_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

public final class RawXDGWMBase {
    let pointer: OpaquePointer
    public let version: RawVersion

    private let owner: XDGWMBaseOwner
    private var isDestroyed = false

    init(pointer wmBasePointer: OpaquePointer, version wmBaseVersion: RawVersion) throws {
        let newOwner = XDGWMBaseOwner(wmBase: wmBasePointer)
        try newOwner.install()

        pointer = wmBasePointer
        version = wmBaseVersion
        owner = newOwner
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

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        swl_xdg_wm_base_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

private enum ListenerInstallState {
    case idle
    case installed
}

private final class XDGWMBaseOwner {
    private let wmBase: OpaquePointer
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_xdg_wm_base_listener_callbacks>
    private var installState = ListenerInstallState.idle

    init(wmBase pointer: OpaquePointer) {
        wmBase = pointer
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: swl_xdg_wm_base_listener_callbacks())

        callbacks.pointee.ping = { data, wmBase, serial in
            guard let data, let wmBase else {
                preconditionFailure("xdg_wm_base ping fired without Swift state")
            }

            _ = CallbackBox<XDGWMBaseOwner>
                .fromOpaque(data)
                .requireOwner()

            // We must pong, otherwise the compositor can treat the app as hung
            swl_xdg_wm_base_pong(wmBase, serial)
        }
    }

    func install() throws {
        guard installState == .idle else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        callbacks.pointee.data = callbackStorage.opaquePointer

        let result = swl_xdg_wm_base_add_listener(wmBase, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        installState = .installed
    }

    deinit {
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}

package final class XDGSurfaceOwner {
    private let configureState: XDGConfigureState
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_xdg_surface_listener_callbacks>
    private var installState = ListenerInstallState.idle

    package init(configureState state: XDGConfigureState) {
        configureState = state
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: swl_xdg_surface_listener_callbacks())

        callbacks.pointee.configure = { data, _, serial in
            guard let data else {
                preconditionFailure("xdg_surface configure fired without Swift state")
            }

            let owner = CallbackBox<XDGSurfaceOwner>
                .fromOpaque(data)
                .requireOwner()
            owner.configureState.handleSurfaceConfigure(serial: serial)
        }
    }

    package func install(on xdgSurface: RawXDGSurface) throws {
        guard installState == .idle else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        callbacks.pointee.data = callbackStorage.opaquePointer

        let result = swl_xdg_surface_add_listener(xdgSurface.pointer, callbacks)

        guard result == 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        installState = .installed
    }

    deinit {
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}

package final class XDGTopLevelOwner {
    private let configureState: XDGConfigureState
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_xdg_toplevel_listener_callbacks>
    private var onClose: (() -> Void)?
    private var installState = ListenerInstallState.idle

    package init(configureState state: XDGConfigureState) {
        configureState = state
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: swl_xdg_toplevel_listener_callbacks())

        callbacks.pointee.configure = { data, _, width, height, _ in
            guard let data else {
                preconditionFailure("xdg_toplevel configure fired without Swift state")
            }

            let owner = CallbackBox<XDGTopLevelOwner>
                .fromOpaque(data)
                .requireOwner()
            owner.configureState.handleTopLevelConfigure(
                width: width,
                height: height
            )
        }

        callbacks.pointee.close = { data, _ in
            guard let data else {
                preconditionFailure("xdg_toplevel close fired without Swift state")
            }

            let owner = CallbackBox<XDGTopLevelOwner>
                .fromOpaque(data)
                .requireOwner()
            owner.onClose?()
        }
    }

    package func install(
        on topLevel: RawXDGTopLevel,
        onClose closeHandler: @escaping () -> Void
    ) throws {
        guard installState == .idle else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        callbacks.pointee.data = callbackStorage.opaquePointer

        let result = swl_xdg_toplevel_add_listener(
            topLevel.pointer,
            callbacks
        )

        guard result == 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        onClose = closeHandler
        installState = .installed
    }

    deinit {
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}
