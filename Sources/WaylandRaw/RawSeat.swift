import CWaylandProtocols
import Glibc

// swiftlint:disable:next type_body_length
public final class RawSeat {
    package let id: RawSeatID
    let pointer: OpaquePointer
    public let version: RawVersion

    private let eventSink: RawInputEventSink
    private let proxyAdoption: RawProxyAdoptionContext?
    private let invariantFailureSink: RawInvariantFailureSink?
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
        proxyAdoption adoptionContext: RawProxyAdoptionContext? = nil,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        operations seatOperations: RawSeatProxyOperations = .live,
        installListener: Bool = true
    ) throws {
        id = seatID
        pointer = adoptionContext?.adopt(seatPointer, interface: "wl_seat") ?? seatPointer
        version = seatVersion
        eventSink = inputEventSink
        proxyAdoption = adoptionContext
        invariantFailureSink = failureSink ?? adoptionContext?.invariantFailureSink
        operations = seatOperations
        listenerOwner = SeatListenerOwner(
            operations: seatOperations,
            invariantFailureSink: failureSink ?? adoptionContext?.invariantFailureSink
        )

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

        let listenerOwner = PointerListenerOwner(
            deviceID: deviceID,
            eventSink: eventSink,
            operations: operations,
            invariantFailureSink: invariantFailureSink
        ) { [weak seat = self] deviceID in
            seat?.isCurrentDevice(deviceID) == true
        }
        do {
            try listenerOwner.install(on: childPointer)
        } catch {
            operations.releasePointer(childPointer)
            throw error
        }

        pointerDevice = RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: operations.proxyVersion(childPointer),
            proxyAdoption: proxyAdoption,
            interface: "wl_pointer",
            listenerOwner: listenerOwner,
            cancelListener: { listenerOwner.cancel() },
            release: operations.releasePointer
        )
    }

    private func createKeyboard(id deviceID: RawInputDeviceID) throws {
        guard keyboardDevice == nil else { return }
        guard let childPointer = operations.getKeyboard(pointer) else {
            throw RuntimeError.bindFailed("wl_keyboard")
        }

        let listenerOwner = KeyboardListenerOwner(
            deviceID: deviceID,
            eventSink: eventSink,
            operations: operations,
            invariantFailureSink: invariantFailureSink,
            isCurrentDevice: { [weak seat = self] deviceID in
                seat?.isCurrentDevice(deviceID) == true
            },
            onError: { [weak seat = self] error in
                seat?.lastCapabilityError = error
                seat?.appendDiagnostic(
                    deviceID: deviceID,
                    operation: .keyboardKeymap,
                    error: error
                )
            }
        )
        do {
            try listenerOwner.install(on: childPointer)
        } catch {
            operations.releaseKeyboard(childPointer)
            throw error
        }

        keyboardDevice = RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: operations.proxyVersion(childPointer),
            proxyAdoption: proxyAdoption,
            interface: "wl_keyboard",
            listenerOwner: listenerOwner,
            cancelListener: { listenerOwner.cancel() },
            release: operations.releaseKeyboard
        )
    }

    private func createTouch(id deviceID: RawInputDeviceID) throws {
        guard touchDevice == nil else { return }
        guard let childPointer = operations.getTouch(pointer) else {
            throw RuntimeError.bindFailed("wl_touch")
        }

        let listenerOwner = TouchListenerOwner(
            deviceID: deviceID,
            eventSink: eventSink,
            operations: operations,
            invariantFailureSink: invariantFailureSink
        ) { [weak seat = self] deviceID in
            seat?.isCurrentDevice(deviceID) == true
        }
        do {
            try listenerOwner.install(on: childPointer)
        } catch {
            operations.releaseTouch(childPointer)
            throw error
        }

        touchDevice = RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: operations.proxyVersion(childPointer),
            proxyAdoption: proxyAdoption,
            interface: "wl_touch",
            listenerOwner: listenerOwner,
            cancelListener: { listenerOwner.cancel() },
            release: operations.releaseTouch
        )
    }

    package func setPointerCursor(
        serial: UInt32,
        surfacePointer: OpaquePointer?,
        hotspotX: Int32,
        hotspotY: Int32
    ) -> RawPointerCursorResult {
        guard let pointerDevice else { return .skippedNoPointer(id) }

        operations.setPointerCursor(
            pointerDevice.pointer,
            serial,
            surfacePointer,
            hotspotX,
            hotspotY,
        )

        return .set(
            RawPointerCursorSetResult(
                seatID: id,
                serial: serial,
                surfaceID: operations.proxyObjectID(surfacePointer),
                hotspotX: hotspotX,
                hotspotY: hotspotY
            )
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

    private func isCurrentDevice(_ deviceID: RawInputDeviceID) -> Bool {
        switch deviceID.kind {
        case .pointer:
            pointerDevice?.id == deviceID
        case .keyboard:
            keyboardDevice?.id == deviceID
        case .touch:
            touchDevice?.id == deviceID
        }
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

    private func appendDiagnostic(
        deviceID: RawInputDeviceID?,
        operation: RawInputDiagnosticOperation,
        error: any Error
    ) {
        eventSink.append(
            RawInputEventDraft(
                seatID: id,
                deviceID: deviceID,
                kind: .diagnostic(
                    RawInputDiagnostic(
                        operation: operation,
                        message: String(describing: error)
                    )
                )
            )
        )
    }

    deinit {
        destroy()
    }
}
