import CWaylandClientSystem
import CWaylandProtocols

final class SyncCallbackOwner {
    private(set) var didFire = false
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_callback_listener_callbacks>

    init() {
        self.callbacks = .allocate(capacity: 1)
        self.callbacks.initialize(to: swl_callback_listener_callbacks())

        self.callbacks.pointee.done = { data, _, _ in
            guard let data else { return }
            let owner = CallbackBox<SyncCallbackOwner>.fromOpaque(data).owner
            owner?.didFire = true
        }
    }

    func install(on callback: OpaquePointer) throws {
        self.callbacks.pointee.data = self.callbackStorage.opaquePointer

        let result = swl_callback_add_listener(callback, self.callbacks)
        guard result == 0 else {
            throw RuntimeError.syncCallbackListenerInstallationFailed
        }
    }

    deinit {
        self.callbacks.deinitialize(count: 1)
        self.callbacks.deallocate()
    }
}
