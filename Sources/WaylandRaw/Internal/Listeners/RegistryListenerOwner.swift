import CWaylandClientSystem
import CWaylandProtocols

@safe
final class RegistryListenerOwner {
    private let state: RegistryState
    private let invariantFailureSink: RawInvariantFailureSink
    var onGlobalRemoved: ((UInt32) -> Void)?
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_registry_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_registry_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(
        state registryState: RegistryState,
        invariantFailureSink failureSink: RawInvariantFailureSink = .init()
    ) {
        state = registryState
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.global = { data, _, name, interface, version in
            guard let interface = unsafe interface else {
                preconditionFailure("wl_registry global fired without Swift state")
            }
            RegistryListenerOwner.withOwner(
                data,
                message: "wl_registry global fired without Swift state"
            ) { owner in
                owner.state.recordGlobal(
                    name: name,
                    interfaceName: unsafe String(cString: interface),
                    version: version
                )
            }
        }

        unsafe callbacks.pointee.global_remove = { data, _, name in
            RegistryListenerOwner.withOwner(
                data,
                message: "wl_registry global_remove fired without Swift state"
            ) { owner in
                owner.state.removeGlobal(name: name)
                owner.onGlobalRemoved?(name)
            }
        }
    }

    func install(on registry: OpaquePointer) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_registry_add_listener(registry, callbacks)
        guard result == 0 else {
            throw RuntimeError.registryListenerInstallationFailed
        }
    }

    func cancel() {
        listenerStorage.invalidate()
        onGlobalRemoved = nil
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RegistryListenerOwner) -> Void
    ) {
        CListenerStorage<RegistryListenerOwner, swl_registry_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}
