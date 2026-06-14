package enum SeatStateError: Error, Equatable, Sendable {
    case activeCapabilityNotAdvertised(
        activeCapabilities: SeatCapabilities,
        advertisedCapabilities: SeatCapabilities
    )
}

package struct SeatState: Equatable, Sendable {
    package private(set) var advertisedCapabilities: SeatCapabilities
    package private(set) var activeCapabilities: SeatCapabilities
    package var pointerGeneration: UInt64
    package var keyboardGeneration: UInt64
    package var touchGeneration: UInt64

    package init() {
        advertisedCapabilities = []
        activeCapabilities = []
        pointerGeneration = 1
        keyboardGeneration = 1
        touchGeneration = 1
    }

    package init(
        advertisedCapabilities seatAdvertisedCapabilities: SeatCapabilities,
        activeCapabilities seatActiveCapabilities: SeatCapabilities,
        pointerGeneration seatPointerGeneration: UInt64 = 1,
        keyboardGeneration seatKeyboardGeneration: UInt64 = 1,
        touchGeneration seatTouchGeneration: UInt64 = 1
    ) throws {
        guard seatActiveCapabilities.isSubset(of: seatAdvertisedCapabilities) else {
            throw SeatStateError.activeCapabilityNotAdvertised(
                activeCapabilities: seatActiveCapabilities,
                advertisedCapabilities: seatAdvertisedCapabilities
            )
        }

        advertisedCapabilities = seatAdvertisedCapabilities
        activeCapabilities = seatActiveCapabilities
        pointerGeneration = seatPointerGeneration
        keyboardGeneration = seatKeyboardGeneration
        touchGeneration = seatTouchGeneration
    }

    package mutating func replaceAdvertisedCapabilities(
        _ seatAdvertisedCapabilities: SeatCapabilities
    ) {
        advertisedCapabilities = seatAdvertisedCapabilities
        activeCapabilities.formIntersection(seatAdvertisedCapabilities)
    }

    package mutating func activate(_ capability: SeatCapabilities) {
        precondition(
            advertisedCapabilities.contains(capability),
            "Seat active capability must be advertised before activation"
        )
        activeCapabilities.insert(capability)
    }

    package mutating func deactivate(_ capability: SeatCapabilities) {
        activeCapabilities.remove(capability)
    }

    package mutating func removeAllCapabilities() {
        advertisedCapabilities = []
        activeCapabilities = []
    }
}

package enum SeatAction: Equatable, Sendable {
    case capabilitiesChanged(SeatCapabilities)
    case pointerCreated
    case pointerCreateFailed
    case pointerDestroyed
    case keyboardCreated
    case keyboardCreateFailed
    case keyboardDestroyed
    case touchCreated
    case touchCreateFailed
    case touchDestroyed
    case removed
}

package struct SeatTransitionPlan: Equatable, Sendable {
    package var effects: [SeatEffect]
    package var nextState: SeatState

    package init(effects transitionEffects: [SeatEffect], nextState transitionState: SeatState) {
        effects = transitionEffects
        nextState = transitionState
    }
}

package enum SeatEffect: Equatable, Sendable {
    case createPointer(RawInputDeviceID)
    case destroyPointer(RawInputDeviceID)
    case createKeyboard(RawInputDeviceID)
    case destroyKeyboard(RawInputDeviceID)
    case createTouch(RawInputDeviceID)
    case destroyTouch(RawInputDeviceID)
    case emitSeatSnapshot
    case emitSeatRemoved
}

package func reduceSeatState(
    _ state: SeatState,
    seatID: RawSeatID,
    action: SeatAction
) -> SeatTransitionPlan {
    switch action {
    case .capabilitiesChanged(let capabilities):
        return planCapabilitiesChanged(state, seatID: seatID, capabilities: capabilities)
    case .pointerCreated:
        return planChildCreated(state, capability: .pointer)
    case .pointerCreateFailed, .pointerDestroyed:
        return planChildRemoved(state, capability: .pointer)
    case .keyboardCreated:
        return planChildCreated(state, capability: .keyboard)
    case .keyboardCreateFailed, .keyboardDestroyed:
        return planChildRemoved(state, capability: .keyboard)
    case .touchCreated:
        return planChildCreated(state, capability: .touch)
    case .touchCreateFailed, .touchDestroyed:
        return planChildRemoved(state, capability: .touch)
    case .removed:
        return planSeatRemoved(state, seatID: seatID)
    }
}

private func planCapabilitiesChanged(
    _ state: SeatState,
    seatID: RawSeatID,
    capabilities: SeatCapabilities
) -> SeatTransitionPlan {
    var next = state
    var effects: [SeatEffect] = []
    let oldActive = state.activeCapabilities

    next.replaceAdvertisedCapabilities(capabilities)

    if oldActive.hasTouch, !capabilities.hasTouch {
        effects.append(.destroyTouch(currentDeviceID(state, seatID: seatID, kind: .touch)))
        next.deactivate(.touch)
    }
    if oldActive.hasKeyboard, !capabilities.hasKeyboard {
        effects.append(.destroyKeyboard(currentDeviceID(state, seatID: seatID, kind: .keyboard)))
        next.deactivate(.keyboard)
    }
    if oldActive.hasPointer, !capabilities.hasPointer {
        effects.append(.destroyPointer(currentDeviceID(state, seatID: seatID, kind: .pointer)))
        next.deactivate(.pointer)
    }

    if capabilities.hasPointer, !oldActive.hasPointer {
        let id = RawInputDeviceID(
            seatID: seatID,
            kind: .pointer,
            generation: next.pointerGeneration
        )
        effects.append(.createPointer(id))
        next.pointerGeneration += 1
        next.activate(.pointer)
    }
    if capabilities.hasKeyboard, !oldActive.hasKeyboard {
        let id = RawInputDeviceID(
            seatID: seatID,
            kind: .keyboard,
            generation: next.keyboardGeneration
        )
        effects.append(.createKeyboard(id))
        next.keyboardGeneration += 1
        next.activate(.keyboard)
    }
    if capabilities.hasTouch, !oldActive.hasTouch {
        let id = RawInputDeviceID(
            seatID: seatID,
            kind: .touch,
            generation: next.touchGeneration
        )
        effects.append(.createTouch(id))
        next.touchGeneration += 1
        next.activate(.touch)
    }

    if next != state || !effects.isEmpty {
        effects.append(.emitSeatSnapshot)
    }

    return SeatTransitionPlan(effects: effects, nextState: next)
}

private func planChildCreated(
    _ state: SeatState,
    capability: SeatCapabilities
) -> SeatTransitionPlan {
    guard !state.activeCapabilities.contains(capability) else {
        return SeatTransitionPlan(effects: [], nextState: state)
    }
    guard state.advertisedCapabilities.contains(capability) else {
        return SeatTransitionPlan(effects: [], nextState: state)
    }

    var next = state
    next.activate(capability)
    return SeatTransitionPlan(effects: [.emitSeatSnapshot], nextState: next)
}

private func planChildRemoved(
    _ state: SeatState,
    capability: SeatCapabilities
) -> SeatTransitionPlan {
    guard state.activeCapabilities.contains(capability) else {
        return SeatTransitionPlan(effects: [], nextState: state)
    }

    var next = state
    next.deactivate(capability)
    return SeatTransitionPlan(effects: [.emitSeatSnapshot], nextState: next)
}

private func planSeatRemoved(_ state: SeatState, seatID: RawSeatID) -> SeatTransitionPlan {
    var effects: [SeatEffect] = []

    if state.activeCapabilities.hasTouch {
        effects.append(.destroyTouch(currentDeviceID(state, seatID: seatID, kind: .touch)))
    }
    if state.activeCapabilities.hasKeyboard {
        effects.append(.destroyKeyboard(currentDeviceID(state, seatID: seatID, kind: .keyboard)))
    }
    if state.activeCapabilities.hasPointer {
        effects.append(.destroyPointer(currentDeviceID(state, seatID: seatID, kind: .pointer)))
    }

    var next = state
    next.removeAllCapabilities()
    effects.append(.emitSeatRemoved)

    return SeatTransitionPlan(effects: effects, nextState: next)
}

private func currentDeviceID(
    _ state: SeatState,
    seatID: RawSeatID,
    kind: RawInputDeviceID.Kind
) -> RawInputDeviceID {
    RawInputDeviceID(
        seatID: seatID,
        kind: kind,
        generation: currentGeneration(state, kind: kind)
    )
}

private func currentGeneration(_ state: SeatState, kind: RawInputDeviceID.Kind) -> UInt64 {
    let nextGeneration =
        switch kind {
        case .pointer:
            state.pointerGeneration
        case .keyboard:
            state.keyboardGeneration
        case .touch:
            state.touchGeneration
        case .tablet:
            UInt64(1)
        }

    return nextGeneration > 1 ? nextGeneration - 1 : 1
}
