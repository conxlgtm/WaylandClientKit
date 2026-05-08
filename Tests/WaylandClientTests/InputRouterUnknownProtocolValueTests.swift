import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct InputRouterUnknownProtocolValueTests {
    @Test
    func unknownPointerButtonStateRoutesAsUnknownAndPublishesDiagnosticOnce() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 7)
        let rawButtonEvent = rawEvent(
            sequence: 10,
            seatID: seatID,
            kind: .pointer(
                .button(
                    RawPointerButton(
                        serial: 11,
                        time: 12,
                        button: 272,
                        state: RawPointerButtonState(rawValue: 99)
                    )
                )
            )
        )

        let first = router.route(rawButtonEvent)
        let second = router.route(rawButtonEvent)

        #expect(first.count == 2)
        #expect(second.count == 1)
        #expect(
            first.first?.kind
                == .pointer(
                    .button(
                        PointerButtonEvent(
                            serial: InputSerial(rawValue: 11),
                            time: WaylandTimestampMilliseconds(rawValue: 12),
                            button: PointerButtonCode(rawValue: 272),
                            state: .unknown(99)
                        )
                    )
                )
        )
        #expect(
            first.last?.kind
                == .diagnostic(
                    InputDiagnostic(
                        .unknownProtocolValue(
                            UnknownInputProtocolValueDiagnostic(
                                field: .pointerButtonState,
                                rawValue: 99,
                                seatID: SeatID(rawValue: seatID.rawValue),
                                sequence: 10
                            )
                        )
                    )
                )
        )
    }

    @Test
    func unknownKeyboardKeyStateRoutesAsUnknownAndPublishesDiagnosticOnce() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 8)
        let rawKeyEvent = rawEvent(
            sequence: 20,
            seatID: seatID,
            kind: .keyboard(
                .key(
                    RawKeyboardKey(
                        serial: 21,
                        time: 22,
                        evdevKeycode: 30,
                        state: RawKeyboardKeyState(rawValue: 99)
                    )
                )
            )
        )

        let first = router.route(rawKeyEvent)
        let second = router.route(rawKeyEvent)

        #expect(first.count == 2)
        #expect(second.count == 1)
        #expect(
            first.first?.kind
                == .keyboard(
                    .raw(
                        .key(
                            KeyboardKeyEvent(
                                serial: InputSerial(rawValue: 21),
                                time: WaylandTimestampMilliseconds(rawValue: 22),
                                rawKeycode: EvdevKeycode(rawValue: 30),
                                state: .unknown(99)
                            )
                        )
                    )
                )
        )
        #expect(
            first.last?.kind
                == .diagnostic(
                    InputDiagnostic(
                        .unknownProtocolValue(
                            UnknownInputProtocolValueDiagnostic(
                                field: .keyboardKeyState,
                                rawValue: 99,
                                seatID: SeatID(rawValue: seatID.rawValue),
                                sequence: 20
                            )
                        )
                    )
                )
        )
    }

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
