import CWaylandClientSystem
import CWaylandProtocols

final class RegistryListenerOwner {
    private let state: RegistryState
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_registry_listener_callbacks>

    init(state: RegistryState) {
        self.state = state
        self.callbacks = .allocate(capacity: 1)
        self.callbacks.initialize(to: swl_registry_listener_callbacks())

        self.callbacks.pointee.global = { data, _, name, interface, version in
            guard let data, let interface else { return }
            let owner = CallbackBox<RegistryListenerOwner>.fromOpaque(data).owner
            owner?.state.recordGlobal(
                name: name,
                interfaceName: String(cString: interface),
                version: version
            )
        }

        self.callbacks.pointee.global_remove = { data, _, name in
            guard let data else { return }
            let owner = CallbackBox<RegistryListenerOwner>.fromOpaque(data).owner
            owner?.state.removeGlobal(name: name)
        }
    }

    func install(on registry: OpaquePointer) throws {
        self.callbacks.pointee.data = self.callbackStorage.opaquePointer

        let result = swl_registry_add_listener(registry, self.callbacks)
        guard result == 0 else {
            throw RuntimeError.registryListenerInstallationFailed
        }
    }

    deinit {
        self.callbacks.deinitialize(count: 1)
        self.callbacks.deallocate()
    }
}
