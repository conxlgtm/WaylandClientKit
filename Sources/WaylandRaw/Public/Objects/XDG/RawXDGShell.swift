import CWaylandClientSystem
import CWaylandProtocols

@safe
package final class RawXDGTopLevel {
    @safe let pointer: OpaquePointer
    package let version: RawVersion

    private var isDestroyed = false

    #if DEBUG
        package var pointerAddressForTesting: UInt {
            unsafe UInt(bitPattern: UnsafeMutableRawPointer(pointer))
        }
    #endif

    @safe
    init(
        pointer topLevelPointer: OpaquePointer,
        version topLevelVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            pointer = try adoptionContext.adopt(topLevelPointer, interface: "xdg_toplevel")
        } catch {
            unsafe swl_xdg_toplevel_destroy(topLevelPointer)
            throw error
        }
        version = topLevelVersion
    }

    package func setTitle(_ title: String) {
        unsafe title.withCString { titlePointer in
            unsafe swl_xdg_toplevel_set_title(pointer, titlePointer)
        }
    }

    package func setAppID(_ appID: String) {
        unsafe appID.withCString { appIDPointer in
            unsafe swl_xdg_toplevel_set_app_id(pointer, appIDPointer)
        }
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        unsafe swl_xdg_toplevel_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawXDGSurface {
    @safe let pointer: OpaquePointer
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var isDestroyed = false

    @safe
    init(
        pointer surfacePointer: OpaquePointer,
        version surfaceVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            pointer = try adoptionContext.adopt(surfacePointer, interface: "xdg_surface")
        } catch {
            unsafe swl_xdg_surface_destroy(surfacePointer)
            throw error
        }
        version = surfaceVersion
        proxyAdoption = adoptionContext
    }

    package func getTopLevel() throws -> RawXDGTopLevel {
        guard let pointer = unsafe swl_xdg_surface_get_toplevel(pointer) else {
            throw RuntimeError.bindFailed("xdg_toplevel")
        }

        return try .init(pointer: pointer, version: version, proxyAdoption: proxyAdoption)
    }

    package func getPopup(
        parent: RawXDGSurface,
        positioner: RawXDGPositioner
    ) throws -> RawXDGPopup {
        guard
            let popupPointer = unsafe swl_xdg_surface_get_popup(
                pointer,
                parent.pointer,
                positioner.pointer
            )
        else {
            throw RuntimeError.bindFailed("xdg_popup")
        }

        return try .init(
            pointer: popupPointer,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }

    package func ackConfigure(serial: UInt32) {
        unsafe swl_xdg_surface_ack_configure(pointer, serial)
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        unsafe swl_xdg_surface_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawXDGWMBase {
    @safe let pointer: OpaquePointer
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private let owner: XDGWMBaseOwner
    private var isDestroyed = false

    @safe
    init(
        pointer wmBasePointer: OpaquePointer,
        version wmBaseVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws {
        let newOwner = XDGWMBaseOwner(
            wmBase: wmBasePointer,
            invariantFailureSink: adoptionContext.invariantFailureSink
        )

        do {
            try newOwner.install()
            pointer = try adoptionContext.adopt(wmBasePointer, interface: "xdg_wm_base")
        } catch {
            newOwner.cancel()
            unsafe swl_xdg_wm_base_destroy(wmBasePointer)
            throw error
        }
        version = wmBaseVersion
        proxyAdoption = adoptionContext
        owner = newOwner
    }

    package func getSurface(for surface: RawSurface) throws -> RawXDGSurface {
        guard
            let surfacePointer = unsafe swl_xdg_wm_base_get_xdg_surface(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("xdg_surface")
        }

        return try .init(pointer: surfacePointer, version: version, proxyAdoption: proxyAdoption)
    }

    package func createPositioner() throws -> RawXDGPositioner {
        guard let positionerPointer = unsafe swl_xdg_wm_base_create_positioner(pointer) else {
            throw RuntimeError.bindFailed("xdg_positioner")
        }

        return try .init(
            pointer: positionerPointer,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        owner.cancel()
        unsafe swl_xdg_wm_base_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

package protocol XDGSurfaceConfigureHandling: AnyObject {
    func handleXDGSurfaceConfigure(serial: UInt32)
}

@safe
private final class XDGWMBaseOwner {
    @safe private let wmBase: OpaquePointer
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = ListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_xdg_wm_base_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_xdg_wm_base_listener_callbacks> {
        listenerStorage.callbacks
    }

    @safe
    init(
        wmBase pointer: OpaquePointer,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        unsafe wmBase = pointer
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.ping = { data, wmBase, serial in
            guard let wmBase = unsafe wmBase else {
                preconditionFailure("xdg_wm_base ping fired without Swift state")
            }

            XDGWMBaseOwner.withOwner(
                data,
                message: "xdg_wm_base ping fired without Swift state"
            ) { _ in
                // We must pong, otherwise the compositor can treat the app as hung
                unsafe swl_xdg_wm_base_pong(wmBase, serial)
            }
        }
    }

    func install() throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "xdg_wm_base") {
            unsafe swl_xdg_wm_base_add_listener(wmBase, callbacks)
        }
    }

    func cancel() {
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (XDGWMBaseOwner) -> Void
    ) {
        CListenerStorage<XDGWMBaseOwner, swl_xdg_wm_base_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

@safe
package final class XDGSurfaceOwner {
    private let configureHandler: any XDGSurfaceConfigureHandling
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = ListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_xdg_surface_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_xdg_surface_listener_callbacks> {
        listenerStorage.callbacks
    }

    package init(
        configureState state: XDGConfigureState,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        configureHandler = state
        invariantFailureSink = failureSink
        installCallback()
    }

    package init(
        configureHandler handler: any XDGSurfaceConfigureHandling,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        configureHandler = handler
        invariantFailureSink = failureSink
        installCallback()
    }

    private func installCallback() {
        unsafe callbacks.pointee.configure = { data, _, serial in
            XDGSurfaceOwner.withOwner(
                data,
                message: "xdg_surface configure fired without Swift state"
            ) { owner in
                owner.configureHandler.handleXDGSurfaceConfigure(serial: serial)
            }
        }
    }

    package func install(on xdgSurface: RawXDGSurface) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "xdg_surface") {
            unsafe swl_xdg_surface_add_listener(xdgSurface.pointer, callbacks)
        }
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (XDGSurfaceOwner) -> Void
    ) {
        CListenerStorage<XDGSurfaceOwner, swl_xdg_surface_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

@safe
package final class XDGTopLevelOwner {
    private let configureState: XDGConfigureState
    private let invariantFailureSink: RawInvariantFailureSink?
    private var onClose: (() -> Void)?
    private var installState = ListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_xdg_toplevel_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_xdg_toplevel_listener_callbacks> {
        listenerStorage.callbacks
    }

    package init(
        configureState state: XDGConfigureState,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        configureState = state
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.configure = { data, _, width, height, states in
            XDGTopLevelOwner.withOwner(
                data,
                message: "xdg_toplevel configure fired without Swift state"
            ) { owner in
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
        }

        unsafe callbacks.pointee.close = { data, _ in
            XDGTopLevelOwner.withOwner(
                data,
                message: "xdg_toplevel close fired without Swift state"
            ) { owner in
                owner.onClose?()
            }
        }

        unsafe callbacks.pointee.configure_bounds = { data, _, width, height in
            XDGTopLevelOwner.withOwner(
                data,
                message: "xdg_toplevel configure_bounds fired without Swift state"
            ) { owner in
                owner.configureState.handleConfigureBounds(width: width, height: height)
            }
        }

        unsafe callbacks.pointee.wm_capabilities = { data, _, capabilities in
            XDGTopLevelOwner.withOwner(
                data,
                message: "xdg_toplevel wm_capabilities fired without Swift state"
            ) { owner in
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
    }

    package func install(
        on topLevel: RawXDGTopLevel,
        onClose closeHandler: @escaping () -> Void
    ) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "xdg_toplevel") {
            unsafe swl_xdg_toplevel_add_listener(
                topLevel.pointer,
                callbacks
            )
        }

        onClose = closeHandler
    }

    package func cancel() {
        onClose = nil
        listenerStorage.invalidate()
    }

    @safe
    private static func uint32Array(from array: UnsafeMutablePointer<wl_array>?)
        throws(RuntimeError) -> [UInt32]
    {
        try WaylandArray.uint32Values(from: array)
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (XDGTopLevelOwner) -> Void
    ) {
        CListenerStorage<XDGTopLevelOwner, swl_xdg_toplevel_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}
