import WaylandRaw

struct InputDeviceGraph: Equatable {
    private struct InputDeviceKey: Hashable {
        var seatID: RawSeatID
        var kind: RawInputDeviceID.Kind
    }

    private struct SeatInputState: Equatable {
        var pointer = PointerDeviceState.absent
        var keyboard = KeyboardDeviceState.absent
        var touch = TouchDeviceState.absent

        var isEmpty: Bool {
            pointer == .absent
                && keyboard == .absent
                && touch == .absent
        }

        mutating func adopt(_ deviceID: RawInputDeviceID) {
            switch deviceID.kind {
            case .pointer:
                pointer = .present(identity: .identified(deviceID), focusedSurfaceID: nil)
            case .keyboard:
                keyboard = .present(identity: .identified(deviceID), focusedSurfaceID: nil)
            case .touch:
                touch = .present(
                    identity: .identified(deviceID),
                    focusedSurfaceByTouchID: [:]
                )
            }
        }

        func containsDevice(_ kind: RawInputDeviceID.Kind) -> Bool {
            switch kind {
            case .pointer:
                pointer.isPresent
            case .keyboard:
                keyboard.isPresent
            case .touch:
                touch.isPresent
            }
        }

        func currentDeviceID(_ kind: RawInputDeviceID.Kind) -> RawInputDeviceID? {
            switch kind {
            case .pointer:
                pointer.currentID
            case .keyboard:
                keyboard.currentID
            case .touch:
                touch.currentID
            }
        }

        mutating func retire(_ kind: RawInputDeviceID.Kind) -> RawInputDeviceID? {
            let currentID = currentDeviceID(kind)

            switch kind {
            case .pointer:
                pointer = .absent
            case .keyboard:
                keyboard = .absent
            case .touch:
                touch = .absent
            }

            return currentID
        }
    }

    private var seatsByID: [RawSeatID: SeatInputState] = [:]
    private var lastSeenGenerationByDevice: [InputDeviceKey: UInt64] = [:]

    func pointerFocus(for seatID: RawSeatID) -> RawObjectID? {
        seatsByID[seatID]?.pointer.focusedSurfaceID
    }

    func keyboardFocus(for seatID: RawSeatID) -> RawObjectID? {
        seatsByID[seatID]?.keyboard.focusedSurfaceID
    }

    func touchFocus(for seatID: RawSeatID, touchID: RawTouchID) -> RawObjectID? {
        seatsByID[seatID]?.touch.focus(touchID: touchID)
    }

    mutating func setPointerFocus(seatID: RawSeatID, surfaceID: RawObjectID) {
        updateSeatState(seatID) { state in
            state.pointer.setFocus(surfaceID)
        }
    }

    mutating func setKeyboardFocus(seatID: RawSeatID, surfaceID: RawObjectID) {
        updateSeatState(seatID) { state in
            state.keyboard.setFocus(surfaceID)
        }
    }

    mutating func setTouchFocus(seatID: RawSeatID, touchID: RawTouchID, surfaceID: RawObjectID) {
        updateSeatState(seatID) { state in
            state.touch.setFocus(touchID: touchID, surfaceID: surfaceID)
        }
    }

    mutating func applySeatSnapshot(
        seatID: RawSeatID,
        activeCapabilities: WaylandRaw.SeatCapabilities
    ) {
        if !activeCapabilities.hasPointer {
            retireCurrentDevice(seatID: seatID, kind: .pointer)
        }
        if !activeCapabilities.hasKeyboard {
            retireCurrentDevice(seatID: seatID, kind: .keyboard)
        }
        if !activeCapabilities.hasTouch {
            retireCurrentDevice(seatID: seatID, kind: .touch)
        }
    }

    mutating func acceptDeviceEvent(
        _ deviceID: RawInputDeviceID?,
        seatID: RawSeatID,
        kind: RawInputDeviceID.Kind
    ) -> Bool {
        guard let deviceID else {
            return true
        }

        guard deviceID.seatID == seatID, deviceID.kind == kind else {
            return false
        }

        if currentDeviceID(seatID: seatID, kind: kind) == deviceID {
            return true
        }

        let key = InputDeviceKey(seatID: seatID, kind: kind)
        if let lastSeenGeneration = lastSeenGenerationByDevice[key],
            deviceID.generation <= lastSeenGeneration
        {
            return false
        }

        lastSeenGenerationByDevice[key] = deviceID.generation
        updateSeatState(seatID) { state in
            state.adopt(deviceID)
        }
        return true
    }

    mutating func clearPointerFocus(seatID: RawSeatID, surfaceID: RawObjectID?) {
        guard let surfaceID, pointerFocus(for: seatID) == surfaceID else {
            return
        }

        updateSeatState(seatID) { state in
            state.pointer.clearFocus(matching: surfaceID)
        }
    }

    mutating func clearKeyboardFocus(seatID: RawSeatID, surfaceID: RawObjectID?) {
        guard let surfaceID, keyboardFocus(for: seatID) == surfaceID else {
            return
        }

        updateSeatState(seatID) { state in
            state.keyboard.clearFocus(matching: surfaceID)
        }
    }

    mutating func clearTouchFocus(seatID: RawSeatID, touchID: RawTouchID) {
        updateSeatState(seatID) { state in
            state.touch.clearFocus(touchID: touchID)
        }
    }

    mutating func clearTouchFocuses(seatID: RawSeatID) {
        updateSeatState(seatID) { state in
            state.touch.clearFocuses()
        }
    }

    mutating func removeSeat(_ seatID: RawSeatID) {
        retireCurrentDevice(seatID: seatID, kind: .pointer)
        retireCurrentDevice(seatID: seatID, kind: .keyboard)
        retireCurrentDevice(seatID: seatID, kind: .touch)
        clearGenerationHistory(for: seatID)
        seatsByID[seatID] = nil
    }

    mutating func removeSurface(_ surfaceID: RawObjectID) {
        let seatIDs = seatsByID.keys.sorted { $0.rawValue < $1.rawValue }
        for seatID in seatIDs {
            updateSeatState(seatID) { state in
                if state.pointer.focusedSurfaceID == surfaceID {
                    state.pointer.clearFocus(matching: surfaceID)
                }
                if state.keyboard.focusedSurfaceID == surfaceID {
                    state.keyboard.clearFocus(matching: surfaceID)
                }
                state.touch.removeFocuses(matching: surfaceID)
            }
        }
    }

    private mutating func updateSeatState(
        _ seatID: RawSeatID,
        _ update: (inout SeatInputState) -> Void
    ) {
        var state = seatsByID[seatID] ?? SeatInputState()
        update(&state)
        seatsByID[seatID] = state.isEmpty ? nil : state
    }

    private func currentDeviceID(
        seatID: RawSeatID,
        kind: RawInputDeviceID.Kind
    ) -> RawInputDeviceID? {
        seatsByID[seatID]?.currentDeviceID(kind)
    }

    private mutating func clearGenerationHistory(for seatID: RawSeatID) {
        lastSeenGenerationByDevice[InputDeviceKey(seatID: seatID, kind: .pointer)] = nil
        lastSeenGenerationByDevice[InputDeviceKey(seatID: seatID, kind: .keyboard)] = nil
        lastSeenGenerationByDevice[InputDeviceKey(seatID: seatID, kind: .touch)] = nil
    }

    private mutating func retireCurrentDevice(
        seatID: RawSeatID,
        kind: RawInputDeviceID.Kind
    ) {
        guard let state = seatsByID[seatID], state.containsDevice(kind) else {
            return
        }
        let retiredID = state.currentDeviceID(kind)

        if let retiredID {
            let key = InputDeviceKey(seatID: seatID, kind: kind)
            lastSeenGenerationByDevice[key] = max(
                lastSeenGenerationByDevice[key] ?? 0,
                retiredID.generation
            )
        }

        updateSeatState(seatID) { state in
            _ = state.retire(kind)
        }
    }
}

extension InputRouter {
    func acceptPointerDeviceEvent(_ event: RawInputEvent) -> Bool {
        deviceGraph.acceptDeviceEvent(event.deviceID, seatID: event.seatID, kind: .pointer)
    }

    func acceptKeyboardDeviceEvent(_ event: RawInputEvent) -> Bool {
        deviceGraph.acceptDeviceEvent(event.deviceID, seatID: event.seatID, kind: .keyboard)
    }

    func acceptTouchDeviceEvent(_ event: RawInputEvent) -> Bool {
        deviceGraph.acceptDeviceEvent(event.deviceID, seatID: event.seatID, kind: .touch)
    }

    func applySeatSnapshot(_ event: RawInputEvent, _ snapshot: RawSeatEventSnapshot) {
        deviceGraph.applySeatSnapshot(
            seatID: event.seatID,
            activeCapabilities: snapshot.activeCapabilities
        )
    }

    func focusedPointerSurface(for seatID: RawSeatID) -> RawObjectID? {
        deviceGraph.pointerFocus(for: seatID)
    }

    func focusedKeyboardSurface(for seatID: RawSeatID) -> RawObjectID? {
        deviceGraph.keyboardFocus(for: seatID)
    }

    func focusedTouchSurface(for seatID: RawSeatID, touchID: RawTouchID) -> RawObjectID? {
        deviceGraph.touchFocus(for: seatID, touchID: touchID)
    }

    func clearTouchFocuses(seatID: RawSeatID) {
        deviceGraph.clearTouchFocuses(seatID: seatID)
    }

    func clearPointerFocus(seatID: RawSeatID, surfaceID: RawObjectID?) {
        deviceGraph.clearPointerFocus(seatID: seatID, surfaceID: surfaceID)
    }

    func clearKeyboardFocus(seatID: RawSeatID, surfaceID: RawObjectID?) {
        deviceGraph.clearKeyboardFocus(seatID: seatID, surfaceID: surfaceID)
    }

    func setPointerFocus(seatID: RawSeatID, surfaceID: RawObjectID) {
        deviceGraph.setPointerFocus(seatID: seatID, surfaceID: surfaceID)
    }

    func setKeyboardFocus(seatID: RawSeatID, surfaceID: RawObjectID) {
        deviceGraph.setKeyboardFocus(seatID: seatID, surfaceID: surfaceID)
    }

    func setTouchFocus(seatID: RawSeatID, touchID: RawTouchID, surfaceID: RawObjectID) {
        deviceGraph.setTouchFocus(seatID: seatID, touchID: touchID, surfaceID: surfaceID)
    }

    func clearTouchFocus(seatID: RawSeatID, touchID: RawTouchID) {
        deviceGraph.clearTouchFocus(seatID: seatID, touchID: touchID)
    }

    func removeSurfaceFromDeviceGraph(_ surfaceID: RawObjectID) {
        deviceGraph.removeSurface(surfaceID)
    }
}
