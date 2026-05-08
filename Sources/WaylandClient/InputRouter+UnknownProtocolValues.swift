import WaylandRaw

extension InputRouter {
    func unknownProtocolValueDiagnostics(for rawEvent: RawInputEvent) -> [InputEvent] {
        guard case .pointer(.axis(let axis)) = rawEvent.kind else {
            return []
        }

        let values: [(UnknownInputProtocolValueField, UInt32)] =
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

        return values.compactMap { field, rawValue in
            unknownProtocolValueDiagnostic(
                field: field,
                rawValue: rawValue,
                rawEvent: rawEvent
            )
        }
    }

    private func unknownPointerAxisValues(
        _ rawAxis: RawPointerAxis
    ) -> [(UnknownInputProtocolValueField, UInt32)] {
        guard case .unknown(let rawValue) = PointerAxis(rawValue: rawAxis.rawValue) else {
            return []
        }

        return [(.pointerAxis, rawValue)]
    }

    private func unknownPointerAxisSourceValues(
        _ source: RawPointerAxisSource
    ) -> [(UnknownInputProtocolValueField, UInt32)] {
        guard case .unknown(let rawValue) = PointerAxisSource(rawValue: source.rawValue) else {
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
                PointerAxisRelativeDirection(rawValue: direction.rawValue)
        else {
            return []
        }

        return [(.pointerAxisRelativeDirection, rawValue)]
    }

    private func unknownProtocolValueDiagnostic(
        field: UnknownInputProtocolValueField,
        rawValue: UInt32,
        rawEvent: RawInputEvent
    ) -> InputEvent? {
        let seatID = SeatID(rawValue: rawEvent.seatID.rawValue)
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
