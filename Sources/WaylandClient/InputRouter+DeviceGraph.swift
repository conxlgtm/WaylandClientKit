import WaylandRaw

struct InputDeviceGraph: Equatable {
    private struct SeatInputState: Equatable {
        var pointer = PointerDeviceState()
        var keyboard = KeyboardDeviceState()
        var touch = TouchDeviceState()

        var isEmpty: Bool {
            pointer == PointerDeviceState()
                && keyboard == KeyboardDeviceState()
                && touch == TouchDeviceState()
        }
    }

    private struct PointerDeviceState: Equatable {
        var focusedSurfaceID: RawObjectID?
    }

    private struct KeyboardDeviceState: Equatable {
        var focusedSurfaceID: RawObjectID?
    }

    private struct TouchDeviceState: Equatable {
        var focusedSurfaceByTouchID: [Int32: RawObjectID] = [:]
    }

    private var seatsByID: [RawSeatID: SeatInputState] = [:]

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
}

extension InputRouter {
    func focusedPointerWindow(for seatID: RawSeatID) -> WindowID? {
        windowID(for: deviceGraph.pointerFocus(for: seatID))
    }

    func focusedKeyboardWindow(for seatID: RawSeatID) -> WindowID? {
        windowID(for: deviceGraph.keyboardFocus(for: seatID))
    }

    func focusedTouchWindow(for seatID: RawSeatID, touchID: Int32) -> WindowID? {
        windowID(for: deviceGraph.touchFocus(for: seatID, touchID: touchID))
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
