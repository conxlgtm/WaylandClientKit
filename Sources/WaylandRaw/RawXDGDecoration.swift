import CWaylandProtocols
import Glibc

package enum RawDecorationMode: Equatable, Sendable {
    case clientSide
    case serverSide

    package init(validating rawValue: UInt32) throws(RuntimeError) {
        switch rawValue {
        case swl_zxdg_toplevel_decoration_v1_mode_client_side():
            self = .clientSide
        case swl_zxdg_toplevel_decoration_v1_mode_server_side():
            self = .serverSide
        default:
            throw .invalidDecorationMode(rawValue)
        }
    }

    package var rawValue: UInt32 {
        switch self {
        case .clientSide:
            swl_zxdg_toplevel_decoration_v1_mode_client_side()
        case .serverSide:
            swl_zxdg_toplevel_decoration_v1_mode_server_side()
        }
    }
}

package final class RawXDGDecorationManager {
    let pointer: OpaquePointer
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var isDestroyed = false

    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            pointer = try adoptionContext.adopt(
                managerPointer,
                interface: "zxdg_decoration_manager_v1"
            )
        } catch {
            unsafe swl_zxdg_decoration_manager_v1_destroy(managerPointer)
            throw error
        }
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
        guard !isDestroyed else { return }

        isDestroyed = true
        unsafe swl_zxdg_decoration_manager_v1_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

package final class RawXDGToplevelDecoration {
    let pointer: OpaquePointer
    package let version: RawVersion

    private var isDestroyed = false

    init(
        pointer decorationPointer: OpaquePointer,
        version decorationVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            pointer = try adoptionContext.adopt(
                decorationPointer,
                interface: "zxdg_toplevel_decoration_v1"
            )
        } catch {
            unsafe swl_zxdg_toplevel_decoration_v1_destroy(decorationPointer)
            throw error
        }
        version = decorationVersion
    }

    package func setMode(_ mode: RawDecorationMode) {
        unsafe swl_zxdg_toplevel_decoration_v1_set_mode(pointer, mode.rawValue)
    }

    package func unsetMode() {
        unsafe swl_zxdg_toplevel_decoration_v1_unset_mode(pointer)
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        unsafe swl_zxdg_toplevel_decoration_v1_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

private enum DecorationListenerInstallState {
    case idle
    case installed
}

private typealias DecorationListenerCallbacks =
    swl_zxdg_toplevel_decoration_v1_listener_callbacks

package final class XDGDecorationOwner {
    private let configureState: XDGConfigureState
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = DecorationListenerInstallState.idle
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zxdg_toplevel_decoration_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    private var callbacks: UnsafeMutablePointer<DecorationListenerCallbacks> {
        listenerStorage.callbacks
    }

    package init(
        configureState state: XDGConfigureState,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        configureState = state
        invariantFailureSink = failureSink

        callbacks.pointee.configure = { data, _, mode in
            XDGDecorationOwner.withOwner(
                data,
                message: "zxdg_toplevel_decoration_v1 configure fired without Swift state"
            ) { owner in
                owner.configureState.handleDecorationConfigure(rawMode: mode)
            }
        }
    }

    package func install(on decoration: RawXDGToplevelDecoration) throws {
        guard installState == .idle else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("zxdg_toplevel_decoration_v1")
            )
        }

        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_zxdg_toplevel_decoration_v1_add_listener(
            decoration.pointer,
            callbacks
        )

        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("zxdg_toplevel_decoration_v1")
            )
        }

        installState = .installed
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

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
