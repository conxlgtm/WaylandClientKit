import CWaylandProtocols
import Glibc

package struct RawXDGActivationTokenValue: Equatable, Hashable, Sendable {
    package let value: String

    package init(_ tokenValue: String) {
        value = tokenValue
    }
}

package enum RawXDGActivationTokenState: Equatable, Sendable {
    case pending
    case done(RawXDGActivationTokenValue)
    case cancelled
    case destroyed
}

@safe
package final class RawXDGActivation {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer activationPointer: OpaquePointer,
        version activationVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = activationVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: activationPointer,
            interface: "xdg_activation_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_xdg_activation_v1_destroy
        )
    }

    package func requestToken(
        onDone handler: @escaping (RawXDGActivationTokenValue) -> Void
    ) throws -> RawXDGActivationToken {
        guard let tokenPointer = unsafe swl_xdg_activation_v1_get_activation_token(pointer)
        else {
            throw RuntimeError.bindFailed("xdg_activation_token_v1")
        }

        let adoptedTokenPointer = try unsafe proxyAdoption.adoptOrDestroy(
            tokenPointer,
            interface: "xdg_activation_token_v1",
            destroy: unsafe swl_xdg_activation_token_v1_destroy
        )

        return try RawXDGActivationToken(
            pointer: adoptedTokenPointer,
            invariantFailureSink: proxyAdoption.invariantFailureSink,
            onDone: handler
        )
    }

    package func activate(token: RawXDGActivationTokenValue, surface: RawSurface) {
        unsafe token.value.withCString { tokenPointer in
            unsafe swl_xdg_activation_v1_activate(pointer, tokenPointer, surface.pointer)
        }
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawXDGActivationToken {
    private let listenerOwner: RawXDGActivationTokenOwner
    private var proxy: RawOwnedProxy
    private(set) package var state: RawXDGActivationTokenState = .pending

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer tokenPointer: OpaquePointer,
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onDone handler: @escaping (RawXDGActivationTokenValue) -> Void
    ) throws(RuntimeError) {
        proxy = RawOwnedProxy(
            pointer: tokenPointer,
            destroy: unsafe swl_xdg_activation_token_v1_destroy
        )
        listenerOwner = RawXDGActivationTokenOwner(
            invariantFailureSink: failureSink,
            onDone: handler
        )
        try unsafe listenerOwner.install(on: tokenPointer) { [weak self] tokenValue in
            self?.markDone(tokenValue)
        }
    }

    package func setSerial(_ serial: UInt32, seat: RawSeat) {
        guard case .pending = state else { return }

        unsafe swl_xdg_activation_token_v1_set_serial(pointer, serial, seat.pointer)
    }

    package func setAppID(_ appID: String) {
        guard case .pending = state else { return }

        unsafe appID.withCString { appIDPointer in
            unsafe swl_xdg_activation_token_v1_set_app_id(pointer, appIDPointer)
        }
    }

    package func setSurface(_ surface: RawSurface) {
        guard case .pending = state else { return }

        unsafe swl_xdg_activation_token_v1_set_surface(pointer, surface.pointer)
    }

    package func commit() {
        guard case .pending = state else { return }

        unsafe swl_xdg_activation_token_v1_commit(pointer)
    }

    package func cancel() {
        guard case .pending = state else { return }

        state = .cancelled
        listenerOwner.cancel()
        proxy.destroy()
    }

    package func destroy() {
        guard state != .destroyed else { return }

        state = .destroyed
        listenerOwner.cancel()
        proxy.destroy()
    }

    private func markDone(_ tokenValue: RawXDGActivationTokenValue) {
        guard case .pending = state else { return }

        state = .done(tokenValue)
        listenerOwner.cancel()
    }

    deinit {
        destroy()
    }
}

@safe
private final class RawXDGActivationTokenOwner {
    private let invariantFailureSink: RawInvariantFailureSink?
    private let onDone: (RawXDGActivationTokenValue) -> Void
    private var isCanceled = false
    private var onTerminal: ((RawXDGActivationTokenValue) -> Void)?
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_xdg_activation_token_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_xdg_activation_token_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        onDone handler: @escaping (RawXDGActivationTokenValue) -> Void
    ) {
        invariantFailureSink = failureSink
        onDone = handler

        unsafe callbacks.pointee.done = { data, _, tokenValue in
            RawXDGActivationTokenOwner.withOwner(
                data,
                message: "xdg_activation_token_v1 done fired without Swift state"
            ) { owner in
                guard !owner.isCanceled, let value = stringFromNullableCString(tokenValue)
                else { return }

                let token = RawXDGActivationTokenValue(value)
                owner.onDone(token)
                owner.onTerminal?(token)
            }
        }
    }

    func install(
        on token: OpaquePointer,
        onTerminal handler: @escaping (RawXDGActivationTokenValue) -> Void
    ) throws(RuntimeError) {
        guard onTerminal == nil else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("xdg_activation_token_v1")
            )
        }

        onTerminal = handler
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_xdg_activation_token_v1_add_listener(token, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("xdg_activation_token_v1")
            )
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawXDGActivationTokenOwner) -> Void
    ) {
        CListenerStorage<
            RawXDGActivationTokenOwner,
            swl_xdg_activation_token_v1_listener_callbacks
        >.withOwner(from: data, message: message(), body)
    }
}
