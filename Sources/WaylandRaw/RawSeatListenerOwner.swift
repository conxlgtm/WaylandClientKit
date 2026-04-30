import CWaylandProtocols

enum SeatListenerEvent {
    case capabilities(SeatCapabilities)
    case name(String)
}

final class SeatListenerOwner {
    private let operations: RawSeatProxyOperations
    private var onEvent: ((SeatListenerEvent) -> Void)?
    private var isCanceled = false
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_seat_listener_callbacks()
    )

    private var callbacks: UnsafeMutablePointer<swl_seat_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(operations seatOperations: RawSeatProxyOperations) {
        operations = seatOperations

        callbacks.pointee.capabilities = { data, _, capabilities in
            guard let data else {
                preconditionFailure("wl_seat capabilities fired without Swift state")
            }

            let owner = CallbackBox<SeatListenerOwner>
                .fromOpaque(data)
                .requireOwner()

            guard !owner.isCanceled else { return }

            owner.onEvent?(.capabilities(SeatCapabilities(rawValue: capabilities)))
        }

        callbacks.pointee.name = { data, _, name in
            guard let data, let name else {
                preconditionFailure("wl_seat name fired without Swift state")
            }

            let owner = CallbackBox<SeatListenerOwner>
                .fromOpaque(data)
                .requireOwner()

            guard !owner.isCanceled else { return }

            owner.onEvent?(.name(String(cString: name)))
        }
    }

    func install(on seat: OpaquePointer, onEvent handleEvent: @escaping (SeatListenerEvent) -> Void)
        throws
    {
        onEvent = handleEvent
        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = operations.addSeatListener(seat, callbacks)
        guard result == 0 else {
            throw RuntimeError.seatListenerInstallationFailed
        }
    }

    func cancel() {
        isCanceled = true
        onEvent = nil
    }

    deinit {
        cancel()
    }
}
