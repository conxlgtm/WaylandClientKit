import CWaylandProtocols
import Glibc

// swiftlint:disable file_length type_body_length
@safe
package final class RawSeat {
    package let id: RawSeatID
    @safe let pointer: OpaquePointer
    package let version: RawVersion

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
        let adoptedPointer: OpaquePointer
        do {
            if let adoptionContext {
                unsafe adoptedPointer = try adoptionContext.adopt(seatPointer, interface: "wl_seat")
            } else {
                unsafe adoptedPointer = seatPointer
            }
        } catch {
            unsafe seatOperations.releaseSeat(seatPointer)
            throw error
        }
        unsafe pointer = adoptedPointer
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

        try unsafe listenerOwner.install(on: adoptedPointer) { [weak seat = self] event in
            seat?.handleSeatEvent(event)
        }
    }

    package var snapshot: RawSeatEventSnapshot {
        RawSeatEventSnapshot(
            uncheckedAdvertisedCapabilities: state.advertisedCapabilities,
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
        nameStorage = name.isEmpty ? nil : name
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
        unsafe operations.releaseSeat(pointer)
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
            attemptCreate(
                action: .pointerCreateFailed,
                deviceID: deviceID,
                interface: "wl_pointer"
            ) {
                try createPointer(id: deviceID)
            }
        case .createKeyboard(let deviceID):
            attemptCreate(
                action: .keyboardCreateFailed,
                deviceID: deviceID,
                interface: "wl_keyboard"
            ) {
                try createKeyboard(id: deviceID)
            }
        case .createTouch(let deviceID):
            attemptCreate(
                action: .touchCreateFailed,
                deviceID: deviceID,
                interface: "wl_touch"
            ) {
                try createTouch(id: deviceID)
            }
        default:
            nil
        }
    }

    private func attemptCreate(
        action failureAction: SeatAction,
        deviceID: RawInputDeviceID,
        interface: String,
        _ create: () throws -> Void
    ) -> Error? {
        do {
            try create()
            return nil
        } catch {
            state = reduceSeatState(state, seatID: id, action: failureAction).nextState
            appendSeatBindingDiagnostic(deviceID: deviceID, interface: interface, error: error)
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
        guard let childPointer = unsafe operations.getPointer(pointer) else {
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
            try unsafe listenerOwner.install(on: childPointer)
        } catch {
            unsafe operations.releasePointer(childPointer)
            throw error
        }

        pointerDevice = try unsafe RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: unsafe operations.proxyVersion(childPointer),
            proxyAdoption: proxyAdoption,
            interface: "wl_pointer",
            listenerOwner: listenerOwner,
            cancelListener: { listenerOwner.cancel() },
            release: operations.releasePointer
        )
    }

    private func createKeyboard(id deviceID: RawInputDeviceID) throws {
        guard keyboardDevice == nil else { return }
        guard let childPointer = unsafe operations.getKeyboard(pointer) else {
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
            onError: { [weak seat = self] error, keymapID in
                seat?.lastCapabilityError = error
                if let keymapID {
                    seat?.appendKeymapDiagnostic(
                        deviceID: deviceID,
                        keymapID: keymapID,
                        error: error
                    )
                } else {
                    seat?.appendListenerDiagnostic(
                        deviceID: deviceID,
                        listener: "wl_keyboard",
                        error: error
                    )
                }
            }
        )
        do {
            try unsafe listenerOwner.install(on: childPointer)
        } catch {
            unsafe operations.releaseKeyboard(childPointer)
            throw error
        }

        keyboardDevice = try unsafe RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: unsafe operations.proxyVersion(childPointer),
            proxyAdoption: proxyAdoption,
            interface: "wl_keyboard",
            listenerOwner: listenerOwner,
            cancelListener: { listenerOwner.cancel() },
            release: operations.releaseKeyboard
        )
    }

    private func createTouch(id deviceID: RawInputDeviceID) throws {
        guard touchDevice == nil else { return }
        guard let childPointer = unsafe operations.getTouch(pointer) else {
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
            try unsafe listenerOwner.install(on: childPointer)
        } catch {
            unsafe operations.releaseTouch(childPointer)
            throw error
        }

        touchDevice = try unsafe RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: unsafe operations.proxyVersion(childPointer),
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

        unsafe operations.setPointerCursor(
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
                surfaceID: unsafe operations.proxyObjectID(surfacePointer),
                hotspotX: hotspotX,
                hotspotY: hotspotY
            )
        )
    }

    package var pointerDevicePointer: OpaquePointer? {
        pointerDevice?.pointer
    }

    package var pointerDeviceID: RawInputDeviceID? {
        pointerDevice?.id
    }

    package func setPointerCursorShape(
        manager cursorShapeManager: RawCursorShapeManager,
        serial: UInt32,
        shape: RawCursorShapeName
    ) throws -> RawPointerCursorResult {
        guard let pointerDevice else { return .skippedNoPointer(id) }

        let shapeDevice = try unsafe cursorShapeManager.cursorShapeDevice(
            forPointer: pointerDevice.pointer
        )
        shapeDevice.setShape(serial: serial, shape: shape)
        shapeDevice.destroy()

        return .set(
            RawPointerCursorSetResult(
                seatID: id,
                serial: serial,
                surfaceID: nil,
                hotspotX: 0,
                hotspotY: 0
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
            RawInputEventDraft(seatID: id, kind: .seat(snapshot))
        )
    }

    private func appendSeatRemoved() {
        eventSink.append(
            RawInputEventDraft(seatID: id, kind: .seatRemoved)
        )
    }

    private func appendKeymapDiagnostic(
        deviceID: RawInputDeviceID?,
        keymapID: RawKeyboardKeymapID,
        error: any Error
    ) {
        let payload: RawInputDiagnosticPayload
        if let keymapError = error as? RawKeyboardKeymapReadError {
            payload = .keymap(.readFailed(id: keymapID, error: keymapError))
        } else {
            payload = .listener(
                RawListenerDiagnostic(
                    listener: "wl_keyboard.keymap",
                    message: String(describing: error)
                )
            )
        }

        eventSink.append(
            RawInputEventDraft.diagnostic(
                seatID: id,
                deviceID: deviceID,
                payload
            )
        )
    }

    private func appendListenerDiagnostic(
        deviceID: RawInputDeviceID?,
        listener: String,
        error: any Error
    ) {
        eventSink.append(
            RawInputEventDraft.diagnostic(
                seatID: id,
                deviceID: deviceID,
                .listener(
                    RawListenerDiagnostic(
                        listener: listener,
                        message: String(describing: error)
                    )
                )
            )
        )
    }

    private func appendSeatBindingDiagnostic(
        deviceID: RawInputDeviceID,
        interface: String,
        error: any Error
    ) {
        guard let runtimeError = error as? RuntimeError else {
            appendListenerDiagnostic(deviceID: deviceID, listener: interface, error: error)
            return
        }

        eventSink.append(
            RawInputEventDraft.diagnostic(
                seatID: id,
                deviceID: deviceID,
                .seatBinding(
                    RawSeatBindingDiagnostic(
                        interface: interface,
                        error: runtimeError
                    )
                )
            )
        )
    }

    deinit {
        destroy()
    }
}
// swiftlint:enable type_body_length
