import CWaylandProtocols
import Glibc

@safe
package final class RawXDGOutputManager {
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
            interface: "zxdg_output_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zxdg_output_manager_v1_destroy
        )
        version = managerVersion
        proxyAdoption = adoptionContext
    }

    package func getXDGOutput(for output: RawOutput) throws(RuntimeError) -> RawXDGOutput {
        guard
            let xdgOutput = unsafe swl_zxdg_output_manager_v1_get_xdg_output(
                pointer,
                output.pointer
            )
        else {
            throw RuntimeError.bindFailed("zxdg_output_v1")
        }

        return try .init(
            pointer: xdgOutput,
            version: version,
            proxyAdoption: proxyAdoption
        ) { [weak output, version] event in
            output?.handleXDGOutputEvent(event, xdgOutputVersion: version)
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
package final class RawXDGOutput {
    package let version: RawVersion

    private var proxy: RawOwnedProxy
    private let listenerOwner: RawXDGOutputListenerOwner

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer outputPointer: OpaquePointer,
        version outputVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        onEvent handleEvent: @escaping (RawXDGOutputEvent) -> Void
    ) throws(RuntimeError) {
        version = outputVersion
        listenerOwner = RawXDGOutputListenerOwner(
            onEvent: handleEvent,
            invariantFailureSink: failureSink
        )
        proxy = try RawOwnedProxy(
            adopting: outputPointer,
            interface: "zxdg_output_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zxdg_output_v1_destroy
        )

        try unsafe listenerOwner.install(on: pointer)
    }

    package func destroy() {
        listenerOwner.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

private enum XDGOutputListenerInstallState {
    case idle
    case installed
}

private typealias XDGOutputListenerCallbacks =
    swl_zxdg_output_v1_listener_callbacks

@safe
private final class RawXDGOutputListenerOwner {
    private let onEvent: (RawXDGOutputEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = XDGOutputListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zxdg_output_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<XDGOutputListenerCallbacks> {
        listenerStorage.callbacks
    }

    init(
        onEvent handleEvent: @escaping (RawXDGOutputEvent) -> Void,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        onEvent = handleEvent
        invariantFailureSink = failureSink

        installLogicalPositionCallback()
        installLogicalSizeCallback()
        installDoneCallback()
        installNameCallback()
        installDescriptionCallback()
    }

    private func installLogicalPositionCallback() {
        unsafe callbacks.pointee.logical_position = { data, _, x, y in
            RawXDGOutputListenerOwner.withOwner(
                data,
                message: "zxdg_output_v1 logical_position fired without Swift state"
            ) { owner in
                owner.onEvent(.logicalPosition(x: x, y: y))
            }
        }
    }

    private func installLogicalSizeCallback() {
        unsafe callbacks.pointee.logical_size = { data, _, width, height in
            RawXDGOutputListenerOwner.withOwner(
                data,
                message: "zxdg_output_v1 logical_size fired without Swift state"
            ) { owner in
                owner.onEvent(.logicalSize(width: width, height: height))
            }
        }
    }

    private func installDoneCallback() {
        unsafe callbacks.pointee.done = { data, _ in
            RawXDGOutputListenerOwner.withOwner(
                data,
                message: "zxdg_output_v1 done fired without Swift state"
            ) { owner in
                owner.onEvent(.done)
            }
        }
    }

    private func installNameCallback() {
        unsafe callbacks.pointee.name = { data, _, name in
            RawXDGOutputListenerOwner.withOwner(
                data,
                message: "zxdg_output_v1 name fired without Swift state"
            ) { owner in
                guard let name = unsafe name else { return }
                owner.onEvent(.name(unsafe String(cString: name)))
            }
        }
    }

    private func installDescriptionCallback() {
        unsafe callbacks.pointee.description = { data, _, description in
            RawXDGOutputListenerOwner.withOwner(
                data,
                message: "zxdg_output_v1 description fired without Swift state"
            ) { owner in
                guard let description = unsafe description else { return }
                owner.onEvent(.description(unsafe String(cString: description)))
            }
        }
    }

    func install(on output: OpaquePointer) throws(RuntimeError) {
        guard installState == .idle else {
            throw listenerInstallError()
        }

        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_zxdg_output_v1_add_listener(output, callbacks)
        guard result == 0 else {
            throw listenerInstallError()
        }

        installState = .installed
    }

    func cancel() {
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawXDGOutputListenerOwner) -> Void
    ) {
        CListenerStorage<
            RawXDGOutputListenerOwner,
            XDGOutputListenerCallbacks
        >
        .withOwner(from: data, message: message(), body)
    }

    private func listenerInstallError() -> RuntimeError {
        RuntimeError.systemError(
            errno: EINVAL,
            operation: .installListener("zxdg_output_v1")
        )
    }
}
