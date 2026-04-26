import CWaylandProtocols

package struct RawSeatProxyOperations {
    package var bindSeat: (OpaquePointer, UInt32, UInt32) -> OpaquePointer?
    package var addSeatListener:
        (OpaquePointer, UnsafePointer<swl_seat_listener_callbacks>) -> Int32
    package var getPointer: (OpaquePointer) -> OpaquePointer?
    package var getKeyboard: (OpaquePointer) -> OpaquePointer?
    package var getTouch: (OpaquePointer) -> OpaquePointer?
    package var proxyVersion: (OpaquePointer) -> RawVersion
    package var releasePointer: (OpaquePointer) -> Void
    package var releaseKeyboard: (OpaquePointer) -> Void
    package var releaseTouch: (OpaquePointer) -> Void
    package var releaseSeat: (OpaquePointer) -> Void

    package static var live: RawSeatProxyOperations {
        RawSeatProxyOperations(
            bindSeat: { registry, name, version in
                swl_registry_bind_wl_seat(registry, name, version)
            },
            addSeatListener: { seat, callbacks in
                swl_seat_add_listener(seat, callbacks)
            },
            getPointer: { seat in
                swl_seat_get_pointer(seat)
            },
            getKeyboard: { seat in
                swl_seat_get_keyboard(seat)
            },
            getTouch: { seat in
                swl_seat_get_touch(seat)
            },
            proxyVersion: { proxy in
                RawVersion(swl_proxy_get_version(UnsafeMutableRawPointer(proxy)))
            },
            releasePointer: { pointer in
                swl_pointer_release(pointer)
            },
            releaseKeyboard: { keyboard in
                swl_keyboard_release(keyboard)
            },
            releaseTouch: { touch in
                swl_touch_release(touch)
            },
            releaseSeat: { seat in
                swl_seat_release(seat)
            }
        )
    }
}

private enum SeatListenerEvent {
    case capabilities(SeatCapabilities)
    case name(String)
}

private final class SeatListenerOwner {
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_seat_listener_callbacks>
    private let operations: RawSeatProxyOperations
    private var onEvent: ((SeatListenerEvent) -> Void)?
    private var isCanceled = false

    init(operations seatOperations: RawSeatProxyOperations) {
        operations = seatOperations
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: swl_seat_listener_callbacks())

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
        callbacks.pointee.data = callbackStorage.opaquePointer

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
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}

package final class RawInputChildProxy {
    package let id: RawInputDeviceID
    package let pointer: OpaquePointer
    package let version: RawVersion

    private let releaseProxy: (OpaquePointer) -> Void
    private var isDestroyed = false

    package init(
        id childID: RawInputDeviceID,
        pointer childPointer: OpaquePointer,
        version childVersion: RawVersion,
        release releaseChildProxy: @escaping (OpaquePointer) -> Void
    ) {
        id = childID
        pointer = childPointer
        version = childVersion
        releaseProxy = releaseChildProxy
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        releaseProxy(pointer)
    }

    deinit {
        destroy()
    }
}

public final class RawSeat {
    package let id: RawSeatID
    let pointer: OpaquePointer
    public let version: RawVersion

    private let eventSink: RawInputEventSink
    private let listenerOwner: SeatListenerOwner
    private let operations: RawSeatProxyOperations
    private var state = SeatState()
    private var nameStorage: String?
    private var pointerDevice: RawInputChildProxy?
    private var keyboardDevice: RawInputChildProxy?
    private var touchDevice: RawInputChildProxy?
    private var isDestroyed = false

    package private(set) var lastCapabilityError: Error?

    package var advertisedCapabilities: SeatCapabilities {
        state.advertisedCapabilities
    }

    package var activeCapabilities: SeatCapabilities {
        state.activeCapabilities
    }

    package var name: String? {
        nameStorage
    }

    package init(
        id seatID: RawSeatID,
        pointer seatPointer: OpaquePointer,
        version seatVersion: RawVersion,
        eventSink inputEventSink: RawInputEventSink,
        operations seatOperations: RawSeatProxyOperations = .live,
        installListener: Bool = true
    ) throws {
        id = seatID
        pointer = seatPointer
        version = seatVersion
        eventSink = inputEventSink
        operations = seatOperations
        listenerOwner = SeatListenerOwner(operations: seatOperations)

        guard installListener else { return }

        try listenerOwner.install(on: seatPointer) { [weak seat = self] event in
            seat?.handleSeatEvent(event)
        }
    }

    package var snapshot: RawSeatEventSnapshot {
        RawSeatEventSnapshot(
            advertisedCapabilities: state.advertisedCapabilities,
            activeCapabilities: state.activeCapabilities,
            name: nameStorage
        )
    }

    package func applyCapabilities(_ capabilities: SeatCapabilities) throws {
        let plan = reduceSeatState(
            state,
            seatID: id,
            action: .capabilitiesChanged(capabilities)
        )
        try apply(plan)
    }

    package func applyName(_ name: String) {
        nameStorage = name
        appendSnapshot()
    }

    package func handleRemovedGlobal() {
        let plan = reduceSeatState(state, seatID: id, action: .removed)
        do {
            try apply(plan)
        } catch {
            lastCapabilityError = error
        }
        destroy()
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        destroyTouch()
        destroyKeyboard()
        destroyPointer()
        listenerOwner.cancel()
        operations.releaseSeat(pointer)
    }

    private func handleSeatEvent(_ event: SeatListenerEvent) {
        do {
            switch event {
            case .capabilities(let capabilities):
                try applyCapabilities(capabilities)
            case .name(let name):
                applyName(name)
            }
        } catch {
            lastCapabilityError = error
        }
    }

    private func apply(_ plan: SeatTransitionPlan) throws {
        state = plan.nextState
        var firstError: Error?

        for effect in plan.effects {
            if let error = applyCreateEffect(effect) {
                firstError = firstError ?? error
                continue
            }

            if applyDestroyEffect(effect) {
                continue
            }

            applyEmissionEffect(effect)
        }

        if let firstError {
            throw firstError
        }
    }

    private func applyCreateEffect(_ effect: SeatEffect) -> Error? {
        switch effect {
        case .createPointer(let deviceID):
            attemptCreate(action: .pointerCreateFailed) {
                try createPointer(id: deviceID)
            }
        case .createKeyboard(let deviceID):
            attemptCreate(action: .keyboardCreateFailed) {
                try createKeyboard(id: deviceID)
            }
        case .createTouch(let deviceID):
            attemptCreate(action: .touchCreateFailed) {
                try createTouch(id: deviceID)
            }
        default:
            nil
        }
    }

    private func attemptCreate(action failureAction: SeatAction, _ create: () throws -> Void)
        -> Error?
    {
        do {
            try create()
            return nil
        } catch {
            state = reduceSeatState(state, seatID: id, action: failureAction).nextState
            return error
        }
    }

    private func applyDestroyEffect(_ effect: SeatEffect) -> Bool {
        switch effect {
        case .destroyPointer:
            destroyPointer()
            return true
        case .destroyKeyboard:
            destroyKeyboard()
            return true
        case .destroyTouch:
            destroyTouch()
            return true
        default:
            return false
        }
    }

    private func applyEmissionEffect(_ effect: SeatEffect) {
        switch effect {
        case .emitSeatSnapshot:
            appendSnapshot()
        case .emitSeatRemoved:
            appendSeatRemoved()
        default:
            break
        }
    }

    private func createPointer(id deviceID: RawInputDeviceID) throws {
        guard pointerDevice == nil else { return }
        guard let childPointer = operations.getPointer(pointer) else {
            throw RuntimeError.bindFailed("wl_pointer")
        }

        pointerDevice = RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: operations.proxyVersion(childPointer),
            release: operations.releasePointer
        )
    }

    private func createKeyboard(id deviceID: RawInputDeviceID) throws {
        guard keyboardDevice == nil else { return }
        guard let childPointer = operations.getKeyboard(pointer) else {
            throw RuntimeError.bindFailed("wl_keyboard")
        }

        keyboardDevice = RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: operations.proxyVersion(childPointer),
            release: operations.releaseKeyboard
        )
    }

    private func createTouch(id deviceID: RawInputDeviceID) throws {
        guard touchDevice == nil else { return }
        guard let childPointer = operations.getTouch(pointer) else {
            throw RuntimeError.bindFailed("wl_touch")
        }

        touchDevice = RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: operations.proxyVersion(childPointer),
            release: operations.releaseTouch
        )
    }

    private func destroyPointer() {
        pointerDevice?.destroy()
        pointerDevice = nil
    }

    private func destroyKeyboard() {
        keyboardDevice?.destroy()
        keyboardDevice = nil
    }

    private func destroyTouch() {
        touchDevice?.destroy()
        touchDevice = nil
    }

    private func appendSnapshot() {
        eventSink.append(
            RawInputEventDraft(
                seatID: id,
                deviceID: nil,
                kind: .seat(snapshot)
            )
        )
    }

    private func appendSeatRemoved() {
        eventSink.append(
            RawInputEventDraft(
                seatID: id,
                deviceID: nil,
                kind: .seatRemoved
            )
        )
    }

    deinit {
        destroy()
    }
}
