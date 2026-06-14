import WaylandRaw

extension InputRouter {
    func unknownProtocolValueDiagnostics(for rawEvent: RawInputEvent) -> [InputEvent] {
        let values: [(UnknownInputProtocolValueField, UInt32)] =
            switch rawEvent.kind {
            case .pointer(.axis(let axis)):
                unknownPointerAxisEventValues(axis)
            case .pointer(.button(let button)):
                unknownPointerButtonStateValues(button.state)
            case .keyboard(.key(let key)):
                unknownKeyboardKeyStateValues(key.state)
            case .seat(let snapshot):
                unknownSeatCapabilityValues(snapshot.advertisedCapabilities)
            case .pointer, .keyboard, .touch, .tablet, .seatRemoved, .diagnostic:
                []
            }

        return values.compactMap { field, rawValue in
            unknownProtocolValueDiagnostic(
                field: field,
                rawValue: rawValue,
                rawEvent: rawEvent
            )
        }
    }

    private func unknownPointerAxisEventValues(
        _ axis: RawPointerAxisEvent
    ) -> [(UnknownInputProtocolValueField, UInt32)] {
        switch axis {
        case .axis(_, let axis, _):
            unknownPointerAxisValues(axis)
        case .source(let source):
            unknownPointerAxisSourceValues(source)
        case .stop(_, let axis), .discrete(let axis, _), .value120(let axis, _):
            unknownPointerAxisValues(axis)
        case .relativeDirection(let axis, let direction):
            unknownPointerAxisAndRelativeDirectionValues(axis, direction)
        case .frame:
            []
        }
    }

    private func unknownPointerAxisValues(
        _ rawAxis: RawPointerAxis
    ) -> [(UnknownInputProtocolValueField, UInt32)] {
        guard case .unknown(let rawValue) = PointerAxis(rawAxis) else {
            return []
        }

        return [(.pointerAxis, rawValue)]
    }

    private func unknownPointerAxisSourceValues(
        _ source: RawPointerAxisSource
    ) -> [(UnknownInputProtocolValueField, UInt32)] {
        guard case .unknown(let rawValue) = PointerAxisSource(source) else {
            return []
        }

        return [(.pointerAxisSource, rawValue)]
    }

    private func unknownPointerAxisAndRelativeDirectionValues(
        _ axis: RawPointerAxis,
        _ direction: RawPointerAxisRelativeDirection
    ) -> [(UnknownInputProtocolValueField, UInt32)] {
        unknownPointerAxisValues(axis) + unknownPointerAxisRelativeDirectionValues(direction)
    }

    private func unknownPointerAxisRelativeDirectionValues(
        _ direction: RawPointerAxisRelativeDirection
    ) -> [(UnknownInputProtocolValueField, UInt32)] {
        guard
            case .unknown(let rawValue) =
                PointerAxisRelativeDirection(direction)
        else {
            return []
        }

        return [(.pointerAxisRelativeDirection, rawValue)]
    }

    private func unknownPointerButtonStateValues(
        _ state: RawPointerButtonState
    ) -> [(UnknownInputProtocolValueField, UInt32)] {
        guard case .unknown(let rawValue) = ButtonState(state) else {
            return []
        }

        return [(.pointerButtonState, rawValue)]
    }

    private func unknownKeyboardKeyStateValues(
        _ state: RawKeyboardKeyState
    ) -> [(UnknownInputProtocolValueField, UInt32)] {
        guard case .unknown(let rawValue) = KeyState(state) else {
            return []
        }

        return [(.keyboardKeyState, rawValue)]
    }

    private func unknownSeatCapabilityValues(
        _ capabilities: WaylandRaw.SeatCapabilities
    ) -> [(UnknownInputProtocolValueField, UInt32)] {
        guard capabilities.hasUnknownBits else {
            return []
        }

        return [(.seatCapability, capabilities.unknownBits)]
    }

    private func unknownProtocolValueDiagnostic(
        field: UnknownInputProtocolValueField,
        rawValue: UInt32,
        rawEvent: RawInputEvent
    ) -> InputEvent? {
        let seatID = SeatID(rawEvent.seatID)
        let key = ReportedUnknownInputProtocolValue(
            seatID: seatID,
            field: field,
            rawValue: rawValue
        )
        guard reportedUnknownProtocolValues.insert(key).inserted else {
            return nil
        }

        return routedEvent(
            rawEvent,
            target: .display,
            kind: .diagnostic(
                InputDiagnostic(
                    .unknownProtocolValue(
                        UnknownInputProtocolValueDiagnostic(
                            field: field,
                            rawValue: rawValue,
                            seatID: seatID,
                            sequence: rawEvent.sequence
                        )
                    )
                )
            )
        )
    }
}
