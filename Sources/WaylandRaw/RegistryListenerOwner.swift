import CWaylandClientSystem
import CWaylandProtocols

final class RegistryListenerOwner {
    private let state: RegistryState
    var onGlobalRemoved: ((UInt32) -> Void)?
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_registry_listener_callbacks()
    )

    private var callbacks: UnsafeMutablePointer<swl_registry_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(state registryState: RegistryState) {
        state = registryState

        callbacks.pointee.global = { data, _, name, interface, version in
            guard let data, let interface else {
                preconditionFailure("wl_registry global fired without Swift state")
            }
            let owner = CallbackBox<RegistryListenerOwner>
                .fromOpaque(data)
                .requireOwner()
            owner.state.recordGlobal(
                name: name,
                interfaceName: String(cString: interface),
                version: version
            )
        }

        callbacks.pointee.global_remove = { data, _, name in
            guard let data else {
                preconditionFailure("wl_registry global_remove fired without Swift state")
            }
            let owner = CallbackBox<RegistryListenerOwner>
                .fromOpaque(data)
                .requireOwner()
            owner.state.removeGlobal(name: name)
            owner.onGlobalRemoved?(name)
        }
    }

    func install(on registry: OpaquePointer) throws {
        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = swl_registry_add_listener(registry, callbacks)
        guard result == 0 else {
            throw RuntimeError.registryListenerInstallationFailed
        }
    }
}
