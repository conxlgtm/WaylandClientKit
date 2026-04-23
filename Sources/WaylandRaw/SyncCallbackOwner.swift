import CWaylandClientSystem
import CWaylandProtocols

final class SyncCallbackOwner {
    private(set) var didFire = false
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_callback_listener_callbacks>

    init() {
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: swl_callback_listener_callbacks())

        callbacks.pointee.done = { data, _, _ in
            guard let data else { return }
            let owner = CallbackBox<SyncCallbackOwner>.fromOpaque(data).owner
            owner?.didFire = true
        }
    }

    func install(on callback: OpaquePointer) throws {
        callbacks.pointee.data = callbackStorage.opaquePointer

        let result = swl_callback_add_listener(callback, callbacks)
        guard result == 0 else {
            throw RuntimeError.syncCallbackListenerInstallationFailed
        }
    }

    deinit {
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}
