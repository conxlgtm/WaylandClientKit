import CWaylandProtocols

enum SeatListenerEvent {
    case capabilities(SeatCapabilities)
    case name(String)
}

final class SeatListenerOwner {
    private let operations: RawSeatProxyOperations
    private let invariantFailureSink: RawInvariantFailureSink?
    private var onEvent: ((SeatListenerEvent) -> Void)?
    private var isCanceled = false
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_seat_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    private var callbacks: UnsafeMutablePointer<swl_seat_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(
        operations seatOperations: RawSeatProxyOperations,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        operations = seatOperations
        invariantFailureSink = failureSink

        callbacks.pointee.capabilities = { data, _, capabilities in
            SeatListenerOwner.withOwner(
                data,
                message: "wl_seat capabilities fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }

                owner.onEvent?(.capabilities(SeatCapabilities(rawValue: capabilities)))
            }
        }

        callbacks.pointee.name = { data, _, name in
            SeatListenerOwner.withOwner(
                data,
                message: "wl_seat name fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                guard let name = unsafe name else {
                    owner.reportMissingSeatName()
                    return
                }

                owner.onEvent?(.name(unsafe String(cString: name)))
            }
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
        listenerStorage.invalidate()
    }

    private func reportMissingSeatName() {
        invariantFailureSink?.reportFatalRawInvariantFailure(.missingSeatName)
    }

    deinit {
        cancel()
    }

    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (SeatListenerOwner) -> Void
    ) {
        CListenerStorage<SeatListenerOwner, swl_seat_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}
