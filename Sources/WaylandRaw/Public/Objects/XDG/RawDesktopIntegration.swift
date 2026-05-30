import CWaylandProtocols

@safe
package final class RawXDGToplevelIconManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var listenerInstallState = ListenerInstallState.idle
    private var proxy: RawOwnedProxy

    @safe package var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        installListener shouldInstallListener: Bool = true
    ) throws(RuntimeError) {
        version = managerVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "xdg_toplevel_icon_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_xdg_toplevel_icon_manager_v1_destroy
        )

        if shouldInstallListener {
            do {
                try listenerInstallState.install(interface: "xdg_toplevel_icon_manager_v1") {
                    unsafe swl_xdg_toplevel_icon_manager_v1_add_listener(managerPointer, nil)
                }
            } catch {
                proxy.destroy()
                throw error
            }
        }
    }

    package func createIcon() throws -> RawXDGToplevelIcon {
        guard let iconPointer = unsafe swl_xdg_toplevel_icon_manager_v1_create_icon(pointer)
        else {
            throw RuntimeError.bindFailed("xdg_toplevel_icon_v1")
        }

        let adoptedIconPointer = try unsafe proxyAdoption.adoptOrDestroy(
            iconPointer,
            interface: "xdg_toplevel_icon_v1",
            destroy: unsafe swl_xdg_toplevel_icon_v1_destroy
        )
        return RawXDGToplevelIcon(pointer: adoptedIconPointer)
    }

    package func setIcon(_ icon: RawXDGToplevelIcon?, on topLevel: RawXDGTopLevel) {
        unsafe swl_xdg_toplevel_icon_manager_v1_set_icon(
            pointer,
            topLevel.pointer,
            icon?.pointer
        )
        icon?.markAssigned()
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawXDGToplevelIcon {
    package enum State: Equatable, Sendable {
        case mutable
        case assigned
        case destroyed
    }

    private var proxy: RawOwnedProxy
    private(set) package var state = State.mutable

    @safe var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(pointer iconPointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: iconPointer,
            destroy: unsafe swl_xdg_toplevel_icon_v1_destroy
        )
    }

    package func setName(_ name: String) throws {
        try preconditionMutable()
        unsafe name.withCString { namePointer in
            unsafe swl_xdg_toplevel_icon_v1_set_name(pointer, namePointer)
        }
    }

    package func addBuffer(_ buffer: RawBuffer, scale: Int32) throws {
        try preconditionMutable()
        unsafe swl_xdg_toplevel_icon_v1_add_buffer(pointer, buffer.pointer, scale)
    }

    package func markAssigned() {
        guard state == .mutable else { return }

        state = .assigned
    }

    package func destroy() {
        guard state != .destroyed else { return }

        state = .destroyed
        proxy.destroy()
    }

    private func preconditionMutable() throws {
        guard state == .mutable else {
            throw RuntimeError.invalidArgument("immutable xdg_toplevel_icon_v1")
        }
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawIdleInhibitManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe package var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = managerVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "zwp_idle_inhibit_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zwp_idle_inhibit_manager_v1_destroy
        )
    }

    package func createInhibitor(surface: RawSurface) throws -> RawIdleInhibitor {
        guard
            let inhibitorPointer = unsafe swl_zwp_idle_inhibit_manager_v1_create_inhibitor(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("zwp_idle_inhibitor_v1")
        }

        let adoptedInhibitorPointer = try unsafe proxyAdoption.adoptOrDestroy(
            inhibitorPointer,
            interface: "zwp_idle_inhibitor_v1",
            destroy: unsafe swl_zwp_idle_inhibitor_v1_destroy
        )
        return RawIdleInhibitor(pointer: adoptedInhibitorPointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawIdleInhibitor {
    private var proxy: RawOwnedProxy

    @safe var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(pointer inhibitorPointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: inhibitorPointer,
            destroy: unsafe swl_zwp_idle_inhibitor_v1_destroy
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawSystemBell {
    package let version: RawVersion

    private var proxy: RawOwnedProxy

    @safe package var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer bellPointer: OpaquePointer,
        version bellVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = bellVersion
        proxy = try RawOwnedProxy(
            adopting: bellPointer,
            interface: "xdg_system_bell_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_xdg_system_bell_v1_destroy
        )
    }

    package func ring(surface: RawSurface?) {
        unsafe swl_xdg_system_bell_v1_ring(pointer, surface?.pointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
