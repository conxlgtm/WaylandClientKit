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
    func sessionRoutesConstraintLifecycleTransitionToConstraintSurface() throws {
        let router = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter(
            configuration: .init(compose: .disabled), composeEnvironment: .init())
        let seatID = RawSeatID(rawValue: 21)
        let windowID = WindowID(rawValue: 210)
        let rawIdentity = RawPointerConstraintIdentity(
            objectID: RawObjectID(21),
            kind: .locked
        )
        let id = PointerConstraintID(rawValue: 21, kind: .locked)
        router.register(windowID: windowID, surfaceID: 2_100)

        let routed = routeSessionInputEvents(
            from: [
                rawPointerConstraintEvent(
                    sequence: 1,
                    seatID: seatID,
                    event: .unlocked(rawIdentity, surfaceID: 2_100)
                )
            ],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter
        ) { _ in
            .defunctOneShot(id)
        }

        #expect(routed.count == 1)
        #expect(routed.first?.windowID == windowID)
        #expect(routed.first?.kind == .pointer(.constraintLifecycle(.defunctOneShot(id))))
    }

    @Test
    func sessionRoutesPersistentInactiveConstraintLifecycleTransition() throws {
        let router = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter(
            configuration: .init(compose: .disabled), composeEnvironment: .init())
        let seatID = RawSeatID(rawValue: 23)
        let windowID = WindowID(rawValue: 230)
        let rawIdentity = RawPointerConstraintIdentity(
            objectID: RawObjectID(23),
            kind: .confined
        )
        let id = PointerConstraintID(rawValue: 23, kind: .confined)
        router.register(windowID: windowID, surfaceID: 2_300)

        let routed = routeSessionInputEvents(
            from: [
                rawPointerConstraintEvent(
                    sequence: 1,
                    seatID: seatID,
                    event: .unconfined(rawIdentity, surfaceID: 2_300)
                )
            ],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter
        ) { _ in
            .inactivePersistent(id)
        }

        #expect(routed.count == 1)
        #expect(routed.first?.windowID == windowID)
        #expect(routed.first?.kind == .pointer(.constraintLifecycle(.inactivePersistent(id))))
    }

    @Test
    func sessionDoesNotPublishIgnoredConstraintLifecycleTransition() throws {
        let router = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter(
            configuration: .init(compose: .disabled), composeEnvironment: .init())
        let rawIdentity = RawPointerConstraintIdentity(
            objectID: RawObjectID(22),
            kind: .locked
        )
        router.register(windowID: WindowID(rawValue: 220), surfaceID: 2_200)

        let routed = routeSessionInputEvents(
            from: [
                rawPointerConstraintEvent(
                    sequence: 1,
                    seatID: RawSeatID(rawValue: 22),
                    event: .unlocked(rawIdentity, surfaceID: 2_200)
                )
            ],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter
        ) { _ in
            nil
        }

        #expect(routed.isEmpty)
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

@Suite
struct DisplaySessionPointerCapabilityTests {
    @Test
    func sessionInputCoordinatorReportsPointerCapabilityLoss() throws {
        let coordinator = try makeSessionInputCoordinator()
        let seatID = RawSeatID(rawValue: 44)
        var removedSeats: [SeatID] = []
        var pointerLostSeats: [SeatID] = []

        coordinator.processPendingSessionInputEvents(
            from: [
                rawSeatChanged(
                    sequence: 1,
                    seatID: seatID,
                    name: "seat0",
                    advertisedCapabilities: [.pointer],
                    activeCapabilities: [.pointer]
                ),
                rawSeatChanged(
                    sequence: 2,
                    seatID: seatID,
                    name: "seat0",
                    advertisedCapabilities: [],
                    activeCapabilities: []
                ),
            ],
            onSeatRemoved: { removedSeats.append($0) },
            onPointerCapabilityLost: { pointerLostSeats.append($0) }
        )

        #expect(removedSeats.isEmpty)
        #expect(pointerLostSeats == [SeatID(rawValue: 44)])
    }

    @Test
    func sessionInputCoordinatorDoesNotReportPointerLossForSeatRemoval() throws {
        let coordinator = try makeSessionInputCoordinator()
        let seatID = RawSeatID(rawValue: 45)
        var removedSeats: [SeatID] = []
        var pointerLostSeats: [SeatID] = []

        coordinator.processPendingSessionInputEvents(
            from: [rawEvent(sequence: 1, seatID: seatID, kind: .seatRemoved)],
            onSeatRemoved: { removedSeats.append($0) },
            onPointerCapabilityLost: { pointerLostSeats.append($0) }
        )

        #expect(removedSeats == [SeatID(rawValue: 45)])
        #expect(pointerLostSeats.isEmpty)
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

private func makeSessionInputCoordinator() throws -> SessionInputCoordinator {
    let keyboardInterpreter = try KeyboardInterpreter(
        configuration: .init(compose: .disabled),
        composeEnvironment: .init()
    )
    let cursorManager = try CursorManager(
        backend: RecordingCursorBackend(),
        configuration: .init()
    )
    return SessionInputCoordinator(
        inputRouter: InputRouter(),
        keyboardInterpreter: keyboardInterpreter,
        cursorManager: cursorManager,
        maximumPendingInputEventCount: 16
    )
}
