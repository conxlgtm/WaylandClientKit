import CWaylandProtocols

@safe
package enum RawDecorationMode: Equatable, Sendable {
    case clientSide
    case serverSide
    case unknown(UInt32)

    package init(validating rawValue: UInt32) throws(RuntimeError) {
        switch rawValue {
        case swl_zxdg_toplevel_decoration_v1_mode_client_side():
            self = .clientSide
        case swl_zxdg_toplevel_decoration_v1_mode_server_side():
            self = .serverSide
        default:
            self = .unknown(rawValue)
        }
    }

    package var rawValue: UInt32 {
        switch self {
        case .clientSide:
            swl_zxdg_toplevel_decoration_v1_mode_client_side()
        case .serverSide:
            swl_zxdg_toplevel_decoration_v1_mode_server_side()
        case .unknown(let rawValue):
            rawValue
        }
    }
}

@safe
package final class RawXDGDecorationManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "zxdg_decoration_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zxdg_decoration_manager_v1_destroy
        )
        version = managerVersion
        proxyAdoption = adoptionContext
    }

    package func getTopLevelDecoration(
        for topLevel: RawXDGTopLevel
    ) throws -> RawXDGToplevelDecoration {
        guard
            let pointer = unsafe swl_zxdg_decoration_manager_v1_get_toplevel_decoration(
                pointer,
                topLevel.pointer
            )
        else {
            throw RuntimeError.bindFailed("zxdg_toplevel_decoration_v1")
        }

        return try .init(pointer: pointer, version: version, proxyAdoption: proxyAdoption)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawXDGToplevelDecoration {
    package let version: RawVersion

    private var proxy: RawOwnedProxy

    @safe var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer decorationPointer: OpaquePointer,
        version decorationVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        proxy = try RawOwnedProxy(
            adopting: decorationPointer,
            interface: "zxdg_toplevel_decoration_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zxdg_toplevel_decoration_v1_destroy
        )
        version = decorationVersion
    }

    package func setMode(_ mode: RawDecorationMode) {
        unsafe swl_zxdg_toplevel_decoration_v1_set_mode(pointer, mode.rawValue)
    }

    package func unsetMode() {
        unsafe swl_zxdg_toplevel_decoration_v1_unset_mode(pointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

private typealias DecorationListenerCallbacks =
    swl_zxdg_toplevel_decoration_v1_listener_callbacks

@safe
package final class XDGDecorationOwner {
    private let configureState: XDGConfigureState
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = ListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zxdg_toplevel_decoration_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<DecorationListenerCallbacks> {
        listenerStorage.callbacks
    }

    package init(
        configureState state: XDGConfigureState,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        configureState = state
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.configure = { data, _, mode in
            XDGDecorationOwner.withOwner(
                data,
                message: "zxdg_toplevel_decoration_v1 configure fired without Swift state"
            ) { owner in
                owner.configureState.handleDecorationConfigure(rawMode: mode)
            }
        }
    }

    package func install(on decoration: RawXDGToplevelDecoration) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "zxdg_toplevel_decoration_v1") {
            unsafe swl_zxdg_toplevel_decoration_v1_add_listener(
                decoration.pointer,
                callbacks
            )
        }
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (XDGDecorationOwner) -> Void
    ) {
        CListenerStorage<
            XDGDecorationOwner,
            DecorationListenerCallbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}
