import CWaylandClientSystem
import CWaylandProtocols

final class RegistryListenerOwner {
    private let state: RegistryState
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_registry_listener_callbacks>

    init(state registryState: RegistryState) {
        state = registryState
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: swl_registry_listener_callbacks())

        callbacks.pointee.global = { data, _, name, interface, version in
            guard let data, let interface else { return }
            let owner = CallbackBox<RegistryListenerOwner>.fromOpaque(data).owner
            owner?.state.recordGlobal(
                name: name,
                interfaceName: String(cString: interface),
                version: version
            )
        }

        callbacks.pointee.global_remove = { data, _, name in
            guard let data else { return }
            let owner = CallbackBox<RegistryListenerOwner>.fromOpaque(data).owner
            owner?.state.removeGlobal(name: name)
        }
    }

    func install(on registry: OpaquePointer) throws {
        callbacks.pointee.data = callbackStorage.opaquePointer

        let result = swl_registry_add_listener(registry, callbacks)
        guard result == 0 else {
            throw RuntimeError.registryListenerInstallationFailed
        }
    }

    deinit {
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}
