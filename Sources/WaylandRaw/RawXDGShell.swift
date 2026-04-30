import CWaylandClientSystem
import CWaylandProtocols
import Glibc

public final class RawXDGTopLevel {
    let pointer: OpaquePointer
    public let version: RawVersion

    private var isDestroyed = false

    init(
        pointer topLevelPointer: OpaquePointer,
        version topLevelVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) {
        pointer = adoptionContext.adopt(topLevelPointer, interface: "xdg_toplevel")
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

    private let proxyAdoption: RawProxyAdoptionContext
    private var isDestroyed = false

    init(
        pointer surfacePointer: OpaquePointer,
        version surfaceVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) {
        pointer = adoptionContext.adopt(surfacePointer, interface: "xdg_surface")
        version = surfaceVersion
        proxyAdoption = adoptionContext
    }

    public func getTopLevel() throws -> RawXDGTopLevel {
        guard let pointer = swl_xdg_surface_get_toplevel(pointer) else {
            throw RuntimeError.bindFailed("xdg_toplevel")
        }

        return .init(pointer: pointer, version: version, proxyAdoption: proxyAdoption)
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

    private let proxyAdoption: RawProxyAdoptionContext
    private let owner: XDGWMBaseOwner
    private var isDestroyed = false

    init(
        pointer wmBasePointer: OpaquePointer,
        version wmBaseVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws {
        let newOwner = XDGWMBaseOwner(wmBase: wmBasePointer)
        try newOwner.install()

        pointer = adoptionContext.adopt(wmBasePointer, interface: "xdg_wm_base")
        version = wmBaseVersion
        proxyAdoption = adoptionContext
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

        return .init(pointer: surfacePointer, version: version, proxyAdoption: proxyAdoption)
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
    private var installState = ListenerInstallState.idle
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_xdg_wm_base_listener_callbacks()
    )

    private var callbacks: UnsafeMutablePointer<swl_xdg_wm_base_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(wmBase pointer: OpaquePointer) {
        wmBase = pointer

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

        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = swl_xdg_wm_base_add_listener(wmBase, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        installState = .installed
    }
}

package final class XDGSurfaceOwner {
    private let configureState: XDGConfigureState
    private var installState = ListenerInstallState.idle
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_xdg_surface_listener_callbacks()
    )

    private var callbacks: UnsafeMutablePointer<swl_xdg_surface_listener_callbacks> {
        listenerStorage.callbacks
    }

    package init(configureState state: XDGConfigureState) {
        configureState = state

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

        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = swl_xdg_surface_add_listener(xdgSurface.pointer, callbacks)

        guard result == 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        installState = .installed
    }
}

package final class XDGTopLevelOwner {
    private let configureState: XDGConfigureState
    private var onClose: (() -> Void)?
    private var installState = ListenerInstallState.idle
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_xdg_toplevel_listener_callbacks()
    )

    private var callbacks: UnsafeMutablePointer<swl_xdg_toplevel_listener_callbacks> {
        listenerStorage.callbacks
    }

    package init(configureState state: XDGConfigureState) {
        configureState = state

        callbacks.pointee.configure = { data, _, width, height, states in
            guard let data else {
                preconditionFailure("xdg_toplevel configure fired without Swift state")
            }

            let owner = CallbackBox<XDGTopLevelOwner>
                .fromOpaque(data)
                .requireOwner()
            do {
                owner.configureState.handleTopLevelConfigure(
                    width: width,
                    height: height,
                    states: try XDGTopLevelOwner.uint32Array(from: states).map { rawState in
                        XDGTopLevelState(rawValue: rawState)
                    }
                )
            } catch let error as RuntimeError {
                owner.configureState.recordError(error)
            } catch {
                preconditionFailure("Unexpected XDG configure error: \(error)")
            }
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

        callbacks.pointee.configure_bounds = { data, _, width, height in
            guard let data else {
                preconditionFailure("xdg_toplevel configure_bounds fired without Swift state")
            }

            let owner = CallbackBox<XDGTopLevelOwner>
                .fromOpaque(data)
                .requireOwner()
            owner.configureState.handleConfigureBounds(width: width, height: height)
        }

        callbacks.pointee.wm_capabilities = { data, _, capabilities in
            guard let data else {
                preconditionFailure("xdg_toplevel wm_capabilities fired without Swift state")
            }

            let owner = CallbackBox<XDGTopLevelOwner>
                .fromOpaque(data)
                .requireOwner()
            do {
                owner.configureState.handleWMCapabilities(
                    try XDGTopLevelOwner.uint32Array(from: capabilities).map { rawCapability in
                        XDGWMCapability(rawValue: rawCapability)
                    }
                )
            } catch let error as RuntimeError {
                owner.configureState.recordError(error)
            } catch {
                preconditionFailure("Unexpected XDG capabilities error: \(error)")
            }
        }
    }

    package func install(
        on topLevel: RawXDGTopLevel,
        onClose closeHandler: @escaping () -> Void
    ) throws {
        guard installState == .idle else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

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

    private static func uint32Array(from array: UnsafeMutablePointer<wl_array>?)
        throws(RuntimeError) -> [UInt32]
    {
        try WaylandArray.uint32Values(from: array)
    }
}
