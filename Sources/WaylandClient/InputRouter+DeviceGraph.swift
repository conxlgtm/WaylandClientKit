import WaylandRaw

struct InputDeviceGraph: Equatable {
    private struct InputDeviceKey: Hashable {
        var seatID: RawSeatID
        var kind: RawInputDeviceID.Kind
    }

    private struct SeatInputState: Equatable {
        var pointer = PointerDeviceState()
        var keyboard = KeyboardDeviceState()
        var touch = TouchDeviceState()

        var isEmpty: Bool {
            pointer == PointerDeviceState()
                && keyboard == KeyboardDeviceState()
                && touch == TouchDeviceState()
        }

        mutating func adopt(_ deviceID: RawInputDeviceID) {
            switch deviceID.kind {
            case .pointer:
                pointer = PointerDeviceState(
                    currentID: deviceID,
                    focusedSurfaceID: nil
                )
            case .keyboard:
                keyboard = KeyboardDeviceState(
                    currentID: deviceID,
                    focusedSurfaceID: nil
                )
            case .touch:
                touch = TouchDeviceState(
                    currentID: deviceID,
                    focusedSurfaceByTouchID: [:]
                )
            }
        }

        mutating func retire(_ kind: RawInputDeviceID.Kind) {
            switch kind {
            case .pointer:
                pointer = PointerDeviceState()
            case .keyboard:
                keyboard = KeyboardDeviceState()
            case .touch:
                touch = TouchDeviceState()
            }
        }
    }

    private struct PointerDeviceState: Equatable {
        var currentID: RawInputDeviceID?
        var focusedSurfaceID: RawObjectID?
    }

    private struct KeyboardDeviceState: Equatable {
        var currentID: RawInputDeviceID?
        var focusedSurfaceID: RawObjectID?
    }

    private struct TouchDeviceState: Equatable {
        var currentID: RawInputDeviceID?
        var focusedSurfaceByTouchID: [Int32: RawObjectID] = [:]
    }

    private var seatsByID: [RawSeatID: SeatInputState] = [:]
    private var lastSeenGenerationByDevice: [InputDeviceKey: UInt64] = [:]

    func pointerFocus(for seatID: RawSeatID) -> RawObjectID? {
        seatsByID[seatID]?.pointer.focusedSurfaceID
    }

    func keyboardFocus(for seatID: RawSeatID) -> RawObjectID? {
        seatsByID[seatID]?.keyboard.focusedSurfaceID
    }

    func touchFocus(for seatID: RawSeatID, touchID: Int32) -> RawObjectID? {
        seatsByID[seatID]?.touch.focusedSurfaceByTouchID[touchID]
    }

    mutating func setPointerFocus(seatID: RawSeatID, surfaceID: RawObjectID) {
        updateSeatState(seatID) { state in
            state.pointer.focusedSurfaceID = surfaceID
        }
    }

    mutating func setKeyboardFocus(seatID: RawSeatID, surfaceID: RawObjectID) {
        updateSeatState(seatID) { state in
            state.keyboard.focusedSurfaceID = surfaceID
        }
    }

    mutating func setTouchFocus(seatID: RawSeatID, touchID: Int32, surfaceID: RawObjectID) {
        updateSeatState(seatID) { state in
            state.touch.focusedSurfaceByTouchID[touchID] = surfaceID
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
            state.pointer.focusedSurfaceID = nil
        }
    }

    mutating func clearKeyboardFocus(seatID: RawSeatID, surfaceID: RawObjectID?) {
        guard let surfaceID, keyboardFocus(for: seatID) == surfaceID else {
            return
        }

        updateSeatState(seatID) { state in
            state.keyboard.focusedSurfaceID = nil
        }
    }

    mutating func clearTouchFocus(seatID: RawSeatID, touchID: Int32) {
        updateSeatState(seatID) { state in
            state.touch.focusedSurfaceByTouchID[touchID] = nil
        }
    }

    mutating func clearTouchFocuses(seatID: RawSeatID) {
        updateSeatState(seatID) { state in
            state.touch.focusedSurfaceByTouchID.removeAll()
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
        for seatID in seatsByID.keys {
            updateSeatState(seatID) { state in
                if state.pointer.focusedSurfaceID == surfaceID {
                    state.pointer.focusedSurfaceID = nil
                }
                if state.keyboard.focusedSurfaceID == surfaceID {
                    state.keyboard.focusedSurfaceID = nil
                }
                state.touch.focusedSurfaceByTouchID = state.touch
                    .focusedSurfaceByTouchID
                    .filter { $0.value != surfaceID }
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
        guard let state = seatsByID[seatID] else {
            return nil
        }

        switch kind {
        case .pointer:
            return state.pointer.currentID
        case .keyboard:
            return state.keyboard.currentID
        case .touch:
            return state.touch.currentID
        }
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
        guard let currentID = currentDeviceID(seatID: seatID, kind: kind) else {
            return
        }

        let key = InputDeviceKey(seatID: seatID, kind: kind)
        lastSeenGenerationByDevice[key] = max(
            lastSeenGenerationByDevice[key] ?? 0,
            currentID.generation
        )
        updateSeatState(seatID) { state in
            state.retire(kind)
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

    func focusedTouchSurface(for seatID: RawSeatID, touchID: Int32) -> RawObjectID? {
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

    func setTouchFocus(seatID: RawSeatID, touchID: Int32, surfaceID: RawObjectID) {
        deviceGraph.setTouchFocus(seatID: seatID, touchID: touchID, surfaceID: surfaceID)
    }

    func clearTouchFocus(seatID: RawSeatID, touchID: Int32) {
        deviceGraph.clearTouchFocus(seatID: seatID, touchID: touchID)
    }

    func removeSurfaceFromDeviceGraph(_ surfaceID: RawObjectID) {
        deviceGraph.removeSurface(surfaceID)
    }
}
