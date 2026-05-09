import WaylandRaw

package final class KeyboardInterpreter {
    private enum DeviceResolution {
        case device(RawInputDeviceID)
        case diagnostic(InterpretedKeyboardEvent)
    }

    private let context: XKBContextOwner
    private let configuration: KeyboardInterpreterConfiguration
    private let composeTable: XKBComposeTableOwner?
    private let composeFailureReason: KeyboardInterpretationUnavailableReason?
    private var reportedComposeFailure = false
    private var devicesByID: [RawInputDeviceID: KeyboardInterpreterDeviceState] = [:]
    private let threadAffinity = ThreadAffinity()

    package init(
        configuration interpreterConfiguration: KeyboardInterpreterConfiguration = .init()
    ) throws(KeyboardInterpreterError) {
        do {
            context = try XKBContextOwner()
        } catch {
            throw .contextCreationFailed
        }
        configuration = interpreterConfiguration

        switch interpreterConfiguration.compose {
        case .disabled:
            composeTable = nil
            composeFailureReason = nil
        case .enabled(let locale, _):
            let resolvedLocale = locale.resolved()
            do {
                composeTable = try XKBComposeTableOwner(
                    context: context,
                    locale: resolvedLocale
                )
                composeFailureReason = nil
            } catch let failure {
                composeTable = nil
                composeFailureReason = Self.unavailableReason(for: failure, locale: resolvedLocale)
            }
        case .tableBuffer(let buffer, let locale, _):
            let resolvedLocale = locale.resolved()
            do {
                composeTable = try XKBComposeTableOwner(
                    context: context,
                    buffer: buffer,
                    locale: resolvedLocale
                )
                composeFailureReason = nil
            } catch let failure {
                composeTable = nil
                composeFailureReason = Self.unavailableReason(for: failure, locale: resolvedLocale)
            }
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
        case .diagnostic(let diagnostic):
            consume(diagnostic, from: event)
            return []
        case .pointer, .touch:
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
        return devicesByID[deviceID]?.keymap.validKeymapID
    }

    func keymapState(for deviceID: RawInputDeviceID) -> KeyboardInterpreterKeymapState {
        threadAffinity.preconditionIsOwnerThread()
        return devicesByID[deviceID]?.keymap.snapshot ?? .missing
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

    private func consume(
        _ diagnostic: RawInputDiagnostic,
        from event: RawInputEvent
    ) {
        guard case .keymap(let keymapDiagnostic) = diagnostic.payload else { return }

        guard let deviceID = event.deviceID else { return }
        guard deviceID.kind == .keyboard else { return }

        let (keymapID, reason) = unavailableReason(for: keymapDiagnostic)
        var state = devicesByID[deviceID] ?? KeyboardInterpreterDeviceState()
        state.keymap = .unavailable(keymapID: keymapID, reason: reason)
        devicesByID[deviceID] = state
    }

    private func consumeKey(
        _ key: RawKeyboardKey,
        from event: RawInputEvent
    ) -> [InterpretedKeyboardEvent] {
        switch keyboardDeviceID(from: event) {
        case .diagnostic(let diagnostic):
            return [diagnostic]
        case .device(let deviceID):
            let keymap = devicesByID[deviceID]?.keymap ?? .missing
            guard let layout = keymap.validLayout else {
                let diagnostic = unavailable(
                    keymap.failureReason ?? .missingKeymap,
                    from: event,
                    deviceID: deviceID
                )
                return [diagnostic]
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
            let keymap = devicesByID[deviceID]?.keymap ?? .missing
            guard let layout = keymap.validLayout else {
                let diagnostic = unavailable(
                    keymap.failureReason ?? .missingKeyboardState,
                    from: event,
                    deviceID: deviceID
                )
                return [diagnostic]
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
            var state = devicesByID[deviceID] ?? KeyboardInterpreterDeviceState()
            state.repeatInfo = repeatInfo
            devicesByID[deviceID] = state

            let interpretedEvent = interpreted(
                .repeatInfo(InterpretedKeyboardRepeatInfo(repeatInfo)),
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

        guard case .xkbV1 = payload else {
            var state = devicesByID[payloadDeviceID] ?? KeyboardInterpreterDeviceState()
            state.keymap = .noKeymap(payload.id)
            devicesByID[payloadDeviceID] = state
            return [unavailable(.noKeymap, from: event, deviceID: payloadDeviceID)]
        }

        return installKeymap(payload, deviceID: payloadDeviceID, event: event)
    }

    private func installKeymap(
        _ payload: RawKeyboardKeymapPayload,
        deviceID: RawInputDeviceID,
        event: RawInputEvent
    ) -> [InterpretedKeyboardEvent] {
        do {
            let layout = try KeyboardLayoutState(
                context: context,
                keymap: payload,
                composeTable: composeTable,
                composeCancellationPolicy: composeCancellationPolicy
            )
            var state = devicesByID[deviceID] ?? KeyboardInterpreterDeviceState()
            state.keymap = .valid(layout)
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
            return composeFailureEvent(
                from: event,
                deviceID: deviceID,
                reason: layout.composeFailureReason
            ).map { composeFailure in
                [interpretedEvent, composeFailure]
            } ?? [interpretedEvent]
        } catch .unsupportedKeymapFormat(let format) {
            return markUnavailableAndReport(
                .unsupportedKeymapFormat(format),
                keymapID: payload.id,
                deviceID: deviceID,
                event: event
            )
        } catch .emptyKeymap {
            return markUnavailableAndReport(
                .emptyKeymap,
                keymapID: payload.id,
                deviceID: deviceID,
                event: event
            )
        } catch {
            return markUnavailableAndReport(
                .invalidKeymap,
                keymapID: payload.id,
                deviceID: deviceID,
                event: event
            )
        }
    }

    private var composeCancellationPolicy: KeyboardComposeCancellationPolicy {
        switch configuration.compose {
        case .disabled:
            .passThroughCancellingKey
        case .enabled(_, let policy), .tableBuffer(_, _, let policy):
            policy
        }
    }

    private static func unavailableReason(
        for failure: KeyboardComposeFailure,
        locale: String
    ) -> KeyboardInterpretationUnavailableReason {
        switch failure {
        case .tableUnavailable:
            .composeTableUnavailable(locale: locale)
        case .emptyTableBuffer:
            .emptyComposeTableBuffer
        case .tableBufferContainsNUL:
            .composeTableBufferContainsNUL
        case .stateCreationFailed:
            .composeStateCreationFailed
        }
    }

    private func composeFailureEvent(
        from event: RawInputEvent,
        deviceID: RawInputDeviceID,
        reason layoutFailureReason: KeyboardInterpretationUnavailableReason? = nil
    ) -> InterpretedKeyboardEvent? {
        guard
            !reportedComposeFailure,
            let composeFailureReason = layoutFailureReason ?? composeFailureReason
        else { return nil }
        reportedComposeFailure = true
        return unavailable(composeFailureReason, from: event, deviceID: deviceID)
    }

    private func unavailableReason(
        for diagnostic: RawKeymapDiagnostic
    ) -> (RawKeyboardKeymapID, KeyboardInterpretationUnavailableReason) {
        switch diagnostic {
        case .readFailed(let id, let error):
            (id, .keymapReadFailed(error))
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

    private func markUnavailableAndReport(
        _ reason: KeyboardInterpretationUnavailableReason,
        keymapID: RawKeyboardKeymapID?,
        deviceID: RawInputDeviceID,
        event: RawInputEvent
    ) -> [InterpretedKeyboardEvent] {
        var state = devicesByID[deviceID] ?? KeyboardInterpreterDeviceState()
        state.keymap = .unavailable(keymapID: keymapID, reason: reason)
        devicesByID[deviceID] = state
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
