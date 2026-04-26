final class CListenerStorage<Owner: AnyObject, Callbacks> {
    private let callbackStorage: CallbackBoxStorage<Owner>
    let callbacks: UnsafeMutablePointer<Callbacks>

    init(owner: Owner, initialValue: Callbacks) {
        callbackStorage = CallbackBoxStorage(owner: owner)
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: initialValue)
    }

    var opaqueOwnerPointer: UnsafeMutableRawPointer {
        callbackStorage.opaquePointer
    }

    deinit {
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}
