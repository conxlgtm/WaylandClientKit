import Testing
import WaylandKeyboard
import WaylandRaw

@testable import WaylandClient

@Suite
struct DisplaySessionInputPipelineTests {
    @Test
    func rawKeyboardEventPrecedesInterpretedDiagnosticFromSameRawEvent() throws {
        let router = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter(
            configuration: .init(compose: .disabled), composeEnvironment: .init())
        let seatID = RawSeatID(rawValue: 18)
        let deviceID = RawInputDeviceID(seatID: seatID, kind: .keyboard, generation: 1)
        let windowID = WindowID(rawValue: 180)
        router.register(windowID: windowID, surfaceID: 1_800)
        let enter = rawKeyboardEnter(
            sequence: 1,
            seatID: seatID,
            surfaceID: 1_800,
            deviceID: deviceID
        )

        _ = routeSessionInputEvents(
            from: [enter],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter
        )

        let key = rawKeyboardKey(
            sequence: 2,
            seatID: seatID,
            serial: 12,
            time: 13,
            rawKeycode: 16,
            deviceID: deviceID
        )
        let routed = routeSessionInputEvents(
            from: [key],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter
        )

        #expect(routed.count == 2)
        #expect(routed.map(\.sequence) == [2, 2])
        #expect(routed[0].windowID == windowID)
        #expect(routed[1].windowID == nil)
        #expect(routed[0].kind == expectedRawKeyEvent(serial: 12, time: 13, rawKeycode: 16))
        #expect(
            routed[1].kind
                == .keyboard(
                    .interpreted(
                        .unavailable(
                            WaylandClient.KeyboardInterpretationUnavailable(
                                reason: .missingKeymap
                            )
                        )
                    )
                )
        )
    }

    @Test
    func rawKeymapEventPrecedesInterpreterKeymapDiagnostic() throws {
        let router = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter(
            configuration: .init(compose: .disabled), composeEnvironment: .init())
        let seatID = RawSeatID(rawValue: 19)
        let deviceID = RawInputDeviceID(seatID: seatID, kind: .keyboard, generation: 1)

        let keymap = rawKeyboardKeymap(sequence: 1, seatID: seatID, deviceID: deviceID)
        let routed = routeSessionInputEvents(
            from: [keymap],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter
        )

        #expect(routed.count == 2)
        #expect(routed.map(\.windowID) == [nil, nil])
        #expect(
            routed[0].kind
                == .keyboard(
                    .raw(.keymapChanged(KeyboardKeymapInfo(format: .xkbV1, size: 8)))
                )
        )
        #expect(
            routed[1].kind
                == .keyboard(
                    .interpreted(
                        .unavailable(
                            WaylandClient.KeyboardInterpretationUnavailable(
                                reason: .invalidKeymap
                            )
                        )
                    )
                )
        )
    }

    @Test
    func rawObserverRunsBeforeRoutingAndDoesNotDropInput() throws {
        let router = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter(
            configuration: .init(compose: .disabled), composeEnvironment: .init())
        let observer = RegisteringRawObserver(
            router: router,
            surfaceID: 2_000,
            windowID: WindowID(rawValue: 20)
        )
        let rawEnter = rawPointerEnter(
            sequence: 1,
            seatID: RawSeatID(rawValue: 20),
            surfaceID: 2_000,
            serial: 42
        )

        let routed = routeSessionInputEvents(
            from: [rawEnter],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter,
            rawInputObserver: observer
        )

        #expect(observer.observedSequences == [1])
        #expect(routed.count == 1)
        #expect(routed.first?.windowID == WindowID(rawValue: 20))
        #expect(
            routed.first?.kind
                == .pointer(.entered(PointerLocation(x: 0, y: 0), serial: 42))
        )
    }

    @Test
    func pendingInputOverflowDrainsPrefixThenFailureAndIgnoresFutureInput() {
        var state = PendingInputState.accepting(
            [clientSeatRemoved(sequence: 1)]
        )

        state.append(
            [
                clientSeatRemoved(sequence: 2),
                clientSeatRemoved(sequence: 3),
            ],
            capacity: 2,
            makeOverflowEvent: sessionPendingOverflowEvent
        )

        let drainedEvents = state.drain()

        #expect(drainedEvents.map(\.sequence) == [1, 2, 3])
        #expect(drainedEvents.first?.kind == .seat(.removed))
        #expect(drainedEvents.dropFirst().first?.kind == .seat(.removed))
        #expect(
            drainedEvents.last?.kind
                == .diagnostic(
                    InputDiagnostic(
                        .inputPipelineOverflow(
                            InputPipelineOverflow(
                                stage: .sessionPendingInput,
                                capacity: InputPipelineCapacity(unchecked: 2)
                            )
                        )
                    )
                )
        )

        state.append(
            [clientSeatRemoved(sequence: 4)],
            capacity: 2,
            makeOverflowEvent: sessionPendingOverflowEvent
        )
        #expect(state.drain().isEmpty)
    }

    @Test
    func pendingInputOverflowKeepsAcceptedPrefixFromOverflowingBatch() {
        var state = PendingInputState.accepting([])

        state.append(
            [
                clientSeatRemoved(sequence: 1),
                clientSeatRemoved(sequence: 2),
                clientSeatRemoved(sequence: 3),
            ],
            capacity: 2,
            makeOverflowEvent: sessionPendingOverflowEvent
        )

        let drainedEvents = state.drain()

        #expect(drainedEvents.map(\.sequence) == [1, 2, 3])
        #expect(drainedEvents.first?.kind == .seat(.removed))
        #expect(drainedEvents.dropFirst().first?.kind == .seat(.removed))
        #expect(
            drainedEvents.dropFirst(2).first?.kind
                == .diagnostic(
                    InputDiagnostic(
                        .inputPipelineOverflow(
                            InputPipelineOverflow(
                                stage: .sessionPendingInput,
                                capacity: InputPipelineCapacity(unchecked: 2)
                            )
                        )
                    )
                )
        )
    }

    @Test
    func rawAndPendingInputPipelineOverflowsExposeDistinctStages() {
        let rawOverflow = InputDiagnostic(
            .inputPipelineOverflow(
                InputPipelineOverflow(
                    stage: .rawInputQueue,
                    capacity: InputPipelineCapacity(unchecked: 4)
                )
            )
        )
        let pendingOverflow = sessionPendingOverflowEvent(from: clientSeatRemoved(sequence: 1))

        #expect(
            rawOverflow.operation
                == InputDiagnosticOperation.inputPipelineOverflow(
                    InputPipelineOverflow(
                        stage: .rawInputQueue,
                        capacity: InputPipelineCapacity(unchecked: 4)
                    )
                )
        )
        #expect(
            pendingOverflow.kind
                == .diagnostic(
                    InputDiagnostic(
                        .inputPipelineOverflow(
                            InputPipelineOverflow(
                                stage: .sessionPendingInput,
                                capacity: InputPipelineCapacity(unchecked: 2)
                            )
                        )
                    )
                )
        )
    }
}

private final class RegisteringRawObserver: RawInputEventObserving {
    private let router: InputRouter
    private let surfaceID: RawObjectID
    private let windowID: WindowID

    var observedSequences: [UInt64] = []

    init(
        router inputRouter: InputRouter, surfaceID rawSurfaceID: RawObjectID, windowID id: WindowID
    ) {
        router = inputRouter
        surfaceID = rawSurfaceID
        windowID = id
    }

    func observe(_ rawEvent: RawInputEvent) -> [InputEvent] {
        observedSequences.append(rawEvent.sequence)
        router.register(windowID: windowID, surfaceID: surfaceID)
        return []
    }
}

private func clientSeatRemoved(sequence: UInt64) -> InputEvent {
    InputEvent(
        sequence: sequence,
        seatID: SeatID(rawValue: 42),
        target: .display,
        kind: .seat(.removed)
    )
}

private func expectedRawKeyEvent(
    serial: UInt32,
    time: UInt32,
    rawKeycode: UInt32
) -> InputEventKind {
    .keyboard(
        .raw(
            .key(
                KeyboardKeyEvent(
                    serial: InputSerial(rawValue: serial),
                    time: WaylandTimestampMilliseconds(rawValue: time),
                    rawKeycode: EvdevKeycode(rawValue: rawKeycode),
                    state: .pressed
                )
            )
        )
    )
}

private func sessionPendingOverflowEvent(from event: InputEvent) -> InputEvent {
    InputEvent(
        sequence: event.sequence,
        seatID: event.seatID,
        target: .display,
        kind: .diagnostic(
            InputDiagnostic(
                .inputPipelineOverflow(
                    InputPipelineOverflow(
                        stage: .sessionPendingInput,
                        capacity: InputPipelineCapacity(unchecked: 2)
                    )
                )
            )
        )
    )
}
