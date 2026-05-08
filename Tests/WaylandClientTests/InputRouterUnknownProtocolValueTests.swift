import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct InputRouterUnknownProtocolValueTests {
    @Test
    func unknownPointerAxisValuesRouteAsUnknownDomainValues() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 9)
        router.register(windowID: WindowID(rawValue: 90), surfaceID: 900)
        _ = router.route(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 900))

        let axis = router.route(
            rawEvent(
                sequence: 2,
                seatID: seatID,
                kind: .pointer(
                    .axis(
                        .relativeDirection(
                            axis: RawPointerAxis(rawValue: 77),
                            direction: RawPointerAxisRelativeDirection(rawValue: 88)
                        )
                    )
                )
            )
        )

        #expect(
            axis.first?.kind
                == .pointer(
                    .axis(
                        .relativeDirection(
                            axis: .unknown(77),
                            direction: .unknown(88)
                        )
                    )
                )
        )
        #expect(axis.count == 3)
        #expect(
            axis.dropFirst().map(\.kind)
                == [
                    .diagnostic(
                        InputDiagnostic(
                            .unknownProtocolValue(
                                UnknownInputProtocolValueDiagnostic(
                                    field: .pointerAxis,
                                    rawValue: 77,
                                    seatID: SeatID(rawValue: seatID.rawValue),
                                    sequence: 2
                                )
                            )
                        )
                    ),
                    .diagnostic(
                        InputDiagnostic(
                            .unknownProtocolValue(
                                UnknownInputProtocolValueDiagnostic(
                                    field: .pointerAxisRelativeDirection,
                                    rawValue: 88,
                                    seatID: SeatID(rawValue: seatID.rawValue),
                                    sequence: 2
                                )
                            )
                        )
                    ),
                ]
        )
    }

    @Test
    func unknownPointerAxisSourceDiagnosticIsReportedOncePerSeatAndRawValue() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 6)
        _ = router.route(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 900))
        let rawAxisEvent = rawEvent(
            sequence: 2,
            seatID: seatID,
            kind: .pointer(.axis(.source(RawPointerAxisSource(rawValue: 91))))
        )

        let first = router.route(rawAxisEvent)
        let second = router.route(rawAxisEvent)

        #expect(first.count == 2)
        #expect(second.count == 1)
        #expect(
            first.last?.kind
                == .diagnostic(
                    InputDiagnostic(
                        .unknownProtocolValue(
                            UnknownInputProtocolValueDiagnostic(
                                field: .pointerAxisSource,
                                rawValue: 91,
                                seatID: SeatID(rawValue: seatID.rawValue),
                                sequence: 2
                            )
                        )
                    )
                )
        )
    }
}
