import WaylandRaw

package final class KeyboardInterpreter {
    private enum DeviceResolution {
        case device(RawInputDeviceID)
        case diagnostic(InterpretedKeyboardEvent)
    }

    private struct DeviceState {
        var keymapID: RawKeyboardKeymapID?
        var layout: KeyboardLayoutState?
        var repeatInfo: RawKeyboardRepeatInfo?
    }

    private let context: XKBContextOwner
    private var devicesByID: [RawInputDeviceID: DeviceState] = [:]
    private let threadAffinity = ThreadAffinity()

    package init() throws(KeyboardInterpreterError) {
        do {
            context = try XKBContextOwner()
        } catch {
            throw .contextCreationFailed
        }
    }

    package func consume(_ event: RawInputEvent) -> [InterpretedKeyboardEvent] {
        threadAffinity.preconditionIsOwnerThread()

        switch event.kind {
        case .keyboard(let keyboardEvent):
            return consume(keyboardEvent, from: event)
        case .seat(let snapshot):
            if !snapshot.activeCapabilities.contains(.keyboard) {
                reset(seatID: event.seatID)
            }
            return []
        case .seatRemoved:
            reset(seatID: event.seatID)
            return []
        case .diagnostic, .pointer, .touch:
            return []
        }
    }

    package func reset() {
        threadAffinity.preconditionIsOwnerThread()
        devicesByID.removeAll()
    }

    package func reset(seatID: RawSeatID) {
        threadAffinity.preconditionIsOwnerThread()
        devicesByID = devicesByID.filter { deviceID, _ in
            deviceID.seatID != seatID
        }
    }

    package func reset(deviceID: RawInputDeviceID) {
        threadAffinity.preconditionIsOwnerThread()
        devicesByID.removeValue(forKey: deviceID)
    }

    func keymapID(for deviceID: RawInputDeviceID) -> RawKeyboardKeymapID? {
        threadAffinity.preconditionIsOwnerThread()
        return devicesByID[deviceID]?.keymapID
    }

    func repeatInfo(for deviceID: RawInputDeviceID) -> RawKeyboardRepeatInfo? {
        threadAffinity.preconditionIsOwnerThread()
        return devicesByID[deviceID]?.repeatInfo
    }

    var trackedDeviceIDs: [RawInputDeviceID] {
        threadAffinity.preconditionIsOwnerThread()
        return devicesByID.keys.sorted { lhs, rhs in
            (lhs.seatID.rawValue, lhs.kind.description, lhs.generation)
                < (rhs.seatID.rawValue, rhs.kind.description, rhs.generation)
        }
    }

    deinit {
        threadAffinity.preconditionIsOwnerThread()
    }
}

extension KeyboardInterpreter {
    private func consume(
        _ keyboardEvent: RawKeyboardEvent,
        from event: RawInputEvent
    ) -> [InterpretedKeyboardEvent] {
        switch keyboardEvent {
        case .keymap(let payload):
            return consumeKeymap(payload, from: event)
        case .key(let key):
            return consumeKey(key, from: event)
        case .modifiers(let modifiers):
            return consumeModifiers(modifiers, from: event)
        case .repeatInfo(let repeatInfo):
            return consumeRepeatInfo(repeatInfo, from: event)
        case .enter, .leave:
            return []
        }
    }

    private func consumeKey(
        _ key: RawKeyboardKey,
        from event: RawInputEvent
    ) -> [InterpretedKeyboardEvent] {
        switch keyboardDeviceID(from: event) {
        case .diagnostic(let diagnostic):
            return [diagnostic]
        case .device(let deviceID):
            guard let layout = devicesByID[deviceID]?.layout else {
                return [unavailable(.missingKeymap, from: event, deviceID: deviceID)]
            }

            do {
                let interpretedEvent = interpreted(
                    .key(try layout.interpret(key)),
                    from: event,
                    deviceID: deviceID
                )
                return [interpretedEvent]
            } catch .invalidKeycode(let keycode) {
                return [unavailable(.invalidKeycode(keycode), from: event, deviceID: deviceID)]
            } catch {
                return [unavailable(.missingKeyboardState, from: event, deviceID: deviceID)]
            }
        }
    }

    private func consumeModifiers(
        _ modifiers: RawKeyboardModifiers,
        from event: RawInputEvent
    ) -> [InterpretedKeyboardEvent] {
        switch keyboardDeviceID(from: event) {
        case .diagnostic(let diagnostic):
            return [diagnostic]
        case .device(let deviceID):
            guard let layout = devicesByID[deviceID]?.layout else {
                return [unavailable(.missingKeyboardState, from: event, deviceID: deviceID)]
            }

            let interpretedEvent = interpreted(
                .modifiers(interpretedModifiers(modifiers, layout: layout)),
                from: event,
                deviceID: deviceID
            )
            return [interpretedEvent]
        }
    }

    private func consumeRepeatInfo(
        _ repeatInfo: RawKeyboardRepeatInfo,
        from event: RawInputEvent
    ) -> [InterpretedKeyboardEvent] {
        switch keyboardDeviceID(from: event) {
        case .diagnostic(let diagnostic):
            return [diagnostic]
        case .device(let deviceID):
            var state = devicesByID[deviceID] ?? DeviceState()
            state.repeatInfo = repeatInfo
            devicesByID[deviceID] = state

            let interpretedEvent = interpreted(
                .repeatInfo(
                    InterpretedKeyboardRepeatInfo(
                        rate: repeatInfo.rate,
                        delay: repeatInfo.delay
                    )
                ),
                from: event,
                deviceID: deviceID
            )
            return [interpretedEvent]
        }
    }

    private func consumeKeymap(
        _ payload: RawKeyboardKeymapPayload,
        from event: RawInputEvent
    ) -> [InterpretedKeyboardEvent] {
        let payloadDeviceID = RawInputDeviceID(
            seatID: payload.id.seatID,
            kind: .keyboard,
            generation: payload.id.keyboardGeneration
        )

        if let diagnostic = keymapDeviceDiagnostic(
            eventDeviceID: event.deviceID,
            payloadDeviceID: payloadDeviceID,
            event: event
        ) {
            return [diagnostic]
        }

        if payload.format != .xkbV1 {
            return resetAndReport(
                .unsupportedKeymapFormat(payload.format.rawValue),
                deviceID: payloadDeviceID,
                event: event
            )
        }

        guard !payload.bytes.isEmpty else {
            return resetAndReport(.emptyKeymap, deviceID: payloadDeviceID, event: event)
        }

        return installKeymap(payload, deviceID: payloadDeviceID, event: event)
    }

    private func installKeymap(
        _ payload: RawKeyboardKeymapPayload,
        deviceID: RawInputDeviceID,
        event: RawInputEvent
    ) -> [InterpretedKeyboardEvent] {
        do {
            let layout = try KeyboardLayoutState(context: context, keymap: payload)
            var state = devicesByID[deviceID] ?? DeviceState()
            state.keymapID = payload.id
            state.layout = layout
            devicesByID[deviceID] = state

            let interpretedEvent = interpreted(
                .keymap(
                    InterpretedKeyboardKeymap(
                        id: payload.id,
                        format: payload.format,
                        size: payload.size
                    )
                ),
                from: event,
                deviceID: deviceID
            )
            return [interpretedEvent]
        } catch .unsupportedKeymapFormat(let format) {
            return resetAndReport(
                .unsupportedKeymapFormat(format), deviceID: deviceID, event: event)
        } catch .emptyKeymap {
            return resetAndReport(.emptyKeymap, deviceID: deviceID, event: event)
        } catch {
            return resetAndReport(.invalidKeymap, deviceID: deviceID, event: event)
        }
    }

    private func keyboardDeviceID(from event: RawInputEvent) -> DeviceResolution {
        guard let deviceID = event.deviceID else {
            return .diagnostic(unavailable(.missingDeviceID, from: event))
        }

        guard deviceID.seatID == event.seatID else {
            return .diagnostic(
                unavailable(
                    .mismatchedKeyboardSeat(expected: event.seatID, actual: deviceID.seatID),
                    from: event,
                    deviceID: deviceID
                )
            )
        }

        guard deviceID.kind == .keyboard else {
            return .diagnostic(
                unavailable(.nonKeyboardInputDevice(deviceID), from: event, deviceID: deviceID)
            )
        }

        return .device(deviceID)
    }

    private func keymapDeviceDiagnostic(
        eventDeviceID: RawInputDeviceID?,
        payloadDeviceID: RawInputDeviceID,
        event: RawInputEvent
    ) -> InterpretedKeyboardEvent? {
        guard payloadDeviceID.seatID == event.seatID else {
            return unavailable(
                .mismatchedKeyboardSeat(expected: event.seatID, actual: payloadDeviceID.seatID),
                from: event,
                deviceID: eventDeviceID ?? payloadDeviceID
            )
        }

        guard let eventDeviceID else { return nil }

        guard eventDeviceID.seatID == event.seatID else {
            return unavailable(
                .mismatchedKeyboardSeat(expected: event.seatID, actual: eventDeviceID.seatID),
                from: event,
                deviceID: eventDeviceID
            )
        }

        guard eventDeviceID.kind == .keyboard else {
            return unavailable(
                .nonKeyboardInputDevice(eventDeviceID),
                from: event,
                deviceID: eventDeviceID
            )
        }

        guard eventDeviceID == payloadDeviceID else {
            return unavailable(
                .mismatchedKeyboardDevice(
                    expected: payloadDeviceID,
                    actual: eventDeviceID
                ),
                from: event,
                deviceID: eventDeviceID
            )
        }

        return nil
    }

    private func interpretedModifiers(
        _ modifiers: RawKeyboardModifiers,
        layout: KeyboardLayoutState
    ) -> InterpretedKeyboardModifiers {
        InterpretedKeyboardModifiers(
            serial: modifiers.serial,
            depressed: modifiers.depressed,
            latched: modifiers.latched,
            locked: modifiers.locked,
            group: modifiers.group,
            changedComponents: layout.applyModifiers(modifiers)
        )
    }

    private func resetAndReport(
        _ reason: KeyboardInterpretationUnavailableReason,
        deviceID: RawInputDeviceID,
        event: RawInputEvent
    ) -> [InterpretedKeyboardEvent] {
        devicesByID.removeValue(forKey: deviceID)
        return [unavailable(reason, from: event, deviceID: deviceID)]
    }

    private func interpreted(
        _ kind: InterpretedKeyboardEventKind,
        from event: RawInputEvent,
        deviceID: RawInputDeviceID?
    ) -> InterpretedKeyboardEvent {
        InterpretedKeyboardEvent(
            sequence: event.sequence,
            seatID: event.seatID,
            deviceID: deviceID,
            kind: kind
        )
    }

    private func unavailable(
        _ reason: KeyboardInterpretationUnavailableReason,
        from event: RawInputEvent,
        deviceID: RawInputDeviceID? = nil
    ) -> InterpretedKeyboardEvent {
        interpreted(
            .unavailable(KeyboardInterpretationUnavailable(reason: reason)),
            from: event,
            deviceID: deviceID ?? event.deviceID
        )
    }
}
