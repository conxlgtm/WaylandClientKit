// swiftlint:disable file_length

import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PointerInputRouterTests {
    @Test
    func pointerEnterSetsFocusAndMotionRoutesToFocusedWindow() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 1)
        let windowID = WindowID(rawValue: 10)
        router.register(windowID: windowID, surfaceID: 100)

        let enter = router.route(
            rawPointerEnter(
                sequence: 1, seatID: seatID, surfaceID: 100, serial: 7, xRaw: 256, yRaw: 512)
        )
        let motion = router.route(
            rawPointerMotion(sequence: 2, seatID: seatID, time: 22, xRaw: 768, yRaw: 1_024)
        )
        let expectedEnter = InputEvent(
            sequence: 1,
            seatID: SeatID(rawValue: 1),
            target: .surface(.window(windowID)),
            kind: .pointer(.entered(PointerLocation(x: 1.0, y: 2.0), serial: 7))
        )

        #expect(enter == [expectedEnter])
        #expect(motion.first?.windowID == windowID)
        #expect(motion.first?.kind == .pointer(.moved(PointerLocation(x: 3.0, y: 4.0), time: 22)))
    }

    @Test
    func pointerLeaveOnlyClearsMatchingFocusedSurface() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 2)
        let windowID = WindowID(rawValue: 20)
        router.register(windowID: windowID, surfaceID: 200)
        router.register(windowID: WindowID(rawValue: 21), surfaceID: 201)

        _ = router.route(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 200))
        _ = router.route(rawPointerLeave(sequence: 2, seatID: seatID, surfaceID: 201, serial: 2))
        let motion = router.route(rawPointerMotion(sequence: 3, seatID: seatID, time: 3))

        #expect(motion.first?.windowID == windowID)
    }

    @Test
    func pointerFocusIsPerSeat() {
        let router = InputRouter()
        router.register(windowID: WindowID(rawValue: 30), surfaceID: 300)
        router.register(windowID: WindowID(rawValue: 31), surfaceID: 301)

        _ = router.route(
            rawPointerEnter(sequence: 1, seatID: RawSeatID(rawValue: 1), surfaceID: 300)
        )
        let otherSeatMotion = router.route(
            rawPointerMotion(sequence: 2, seatID: RawSeatID(rawValue: 2), time: 2)
        )

        #expect(otherSeatMotion.first?.windowID == nil)
        #expect(otherSeatMotion.first?.target == .focusless)
    }

    @Test
    func relativePointerMotionRoutesToFocusedPointerSurface() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 32)
        let windowID = WindowID(rawValue: 320)
        router.register(windowID: windowID, surfaceID: 3_200)

        _ = router.route(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 3_200))
        let routed = router.route(rawRelativePointerMotion(sequence: 2, seatID: seatID))

        #expect(routed.first?.windowID == windowID)
        #expect(
            routed.first?.kind
                == .pointer(
                    .relativeMotion(
                        RelativePointerMotionEvent(
                            time: WaylandTimestampMicroseconds(rawValue: 4_294_967_298),
                            delta: PointerDelta(dx: 1.0, dy: -2.0),
                            unacceleratedDelta: PointerDelta(dx: 0.5, dy: -1.0)
                        )
                    )
                )
        )
    }

    @Test
    func pointerConstraintEventsRouteToConstraintSurface() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 33)
        let windowID = WindowID(rawValue: 330)
        let identity = RawPointerConstraintIdentity(
            objectID: RawObjectID(77),
            kind: .locked
        )
        router.register(windowID: windowID, surfaceID: 3_300)

        let rawEvent = rawPointerConstraintEvent(
            sequence: 1,
            seatID: seatID,
            event: .locked(identity, surfaceID: 3_300)
        )
        let accepted = router.acceptRawInputEvent(rawEvent)
        let id = PointerConstraintID(rawValue: 77, kind: .locked)
        let routed =
            accepted.map {
                router.route($0, pointerConstraintLifecycleEvent: .activated(id))
            } ?? []

        #expect(routed.first?.windowID == windowID)
        #expect(
            routed.first?.kind
                == .pointer(
                    .constraintLifecycle(.activated(id))
                )
        )
    }

    @Test
    func pointerConstraintRawEventsWithoutLifecycleTransitionAreNotPublished() {
        let router = InputRouter()
        let identity = RawPointerConstraintIdentity(
            objectID: RawObjectID(78),
            kind: .locked
        )
        router.register(windowID: WindowID(rawValue: 331), surfaceID: 3_301)

        let routed = router.route(
            rawPointerConstraintEvent(
                sequence: 1,
                seatID: RawSeatID(rawValue: 34),
                event: .unlocked(identity, surfaceID: 3_301)
            )
        )

        #expect(routed.isEmpty)
    }

    @Test
    func unregisterClearsPointerFocusForSurface() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 15)
        router.register(windowID: WindowID(rawValue: 150), surfaceID: 1_500)

        _ = router.route(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 1_500))
        router.unregister(surfaceID: 1_500)
        let motion = router.route(rawPointerMotion(sequence: 2, seatID: seatID, time: 2))

        #expect(motion.first?.windowID == nil)
        #expect(motion.first?.target == .focusless)
    }

    @Test
    func unregisterClearsSurfaceFocusAcrossMultipleSeatsAndDevices() {
        let router = InputRouter()
        let removedSurfaceID: RawObjectID = 1_520
        let retainedSurfaceID: RawObjectID = 1_521
        let removedWindowID = WindowID(rawValue: 152)
        let retainedWindowID = WindowID(rawValue: 153)
        let pointerSeatID = RawSeatID(rawValue: 152)
        let keyboardSeatID = RawSeatID(rawValue: 153)
        let touchSeatID = RawSeatID(rawValue: 154)
        let retainedSeatID = RawSeatID(rawValue: 155)

        router.register(windowID: removedWindowID, surfaceID: removedSurfaceID)
        router.register(windowID: retainedWindowID, surfaceID: retainedSurfaceID)
        _ = router.route(
            rawPointerEnter(sequence: 1, seatID: pointerSeatID, surfaceID: removedSurfaceID)
        )
        _ = router.route(
            rawKeyboardEnter(sequence: 2, seatID: keyboardSeatID, surfaceID: removedSurfaceID)
        )
        _ = router.route(
            rawTouchDown(
                sequence: 3,
                seatID: touchSeatID,
                surfaceID: removedSurfaceID,
                id: 7
            )
        )
        _ = router.route(
            rawPointerEnter(sequence: 4, seatID: retainedSeatID, surfaceID: retainedSurfaceID)
        )

        router.unregister(surfaceID: removedSurfaceID)

        let pointerMotion = router.route(
            rawPointerMotion(sequence: 5, seatID: pointerSeatID, time: 5)
        )
        let key = router.route(rawKeyboardKey(sequence: 6, seatID: keyboardSeatID))
        let touchMotion = router.route(rawTouchMotion(sequence: 7, seatID: touchSeatID, id: 7))
        let retainedMotion = router.route(
            rawPointerMotion(sequence: 8, seatID: retainedSeatID, time: 8)
        )

        #expect(pointerMotion.first?.target == .focusless)
        #expect(key.first?.target == .focusless)
        #expect(touchMotion.first?.target == .focusless)
        #expect(retainedMotion.first?.windowID == retainedWindowID)
    }

    @Test
    func pointerButtonAndAxisRouteToFocusedWindow() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 8)
        let windowID = WindowID(rawValue: 80)
        router.register(windowID: windowID, surfaceID: 800)

        _ = router.route(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 800))
        let button = router.route(rawPointerButton(sequence: 2, seatID: seatID))
        let axis = router.route(rawPointerAxis(sequence: 3, seatID: seatID))

        #expect(button.first?.windowID == windowID)
        #expect(
            button.first?.kind
                == .pointer(
                    .button(PointerButtonEvent(serial: 2, time: 3, button: 272, state: .pressed))
                ))
        #expect(axis.first?.windowID == windowID)
        #expect(
            axis.first?.kind
                == .pointer(
                    .axis(.axis(time: 4, axis: .verticalScroll, value: 2.0))
                ))
    }

    @Test
    func unknownSurfaceIsPreservedAsDisplayLevelEvent() {
        let router = InputRouter()

        let routed = router.route(
            rawPointerEnter(sequence: 1, seatID: RawSeatID(rawValue: 5), surfaceID: 999)
        )

        #expect(routed.first?.windowID == nil)
        #expect(routed.first?.target == .unmanagedSurface)
        #expect(
            routed.first?.kind
                == .pointer(
                    .entered(PointerLocation(x: 0, y: 0), serial: 1)
                ))
    }

    @Test
    func pointerMotionAfterUnknownSurfaceEnterStaysUnmanagedSurface() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 17)

        let enter = router.route(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 1_700))
        let motion = router.route(rawPointerMotion(sequence: 2, seatID: seatID, time: 20))

        #expect(enter.first?.target == .unmanagedSurface)
        #expect(motion.first?.windowID == nil)
        #expect(motion.first?.target == .unmanagedSurface)
        #expect(motion.first?.kind == .pointer(.moved(PointerLocation(x: 0, y: 0), time: 20)))
    }
}

@Suite
struct KeyboardFocusInputRouterTests {
    @Test
    func keyboardEnterSetsFocusAndKeyRoutesToFocusedWindow() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 3)
        let windowID = WindowID(rawValue: 40)
        router.register(windowID: windowID, surfaceID: 400)

        _ = router.route(
            rawKeyboardEnter(
                sequence: 1, seatID: seatID, surfaceID: 400, serial: 11, pressedKeys: [30, 31])
        )
        let key = router.route(
            rawKeyboardKey(sequence: 2, seatID: seatID, serial: 12, time: 13, rawKeycode: 32)
        )
        let expectedKey = InputEvent(
            sequence: 2,
            seatID: SeatID(rawValue: 3),
            target: .surface(.window(windowID)),
            kind: .keyboard(
                .raw(
                    .key(
                        KeyboardKeyEvent(
                            serial: 12,
                            time: 13,
                            rawKeycode: 32,
                            state: .pressed
                        )
                    )
                )
            )
        )

        #expect(key == [expectedKey])
    }

    @Test
    func keyboardLeaveClearsMatchingFocusedSurface() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 9)
        let windowID = WindowID(rawValue: 90)
        router.register(windowID: windowID, surfaceID: 900)

        _ = router.route(rawKeyboardEnter(sequence: 1, seatID: seatID, surfaceID: 900))
        let leave = router.route(rawKeyboardLeave(sequence: 2, seatID: seatID, surfaceID: 900))
        let key = router.route(rawKeyboardKey(sequence: 3, seatID: seatID))

        #expect(leave.first?.windowID == windowID)
        #expect(leave.first?.kind == .keyboard(.raw(.left(serial: 2))))
        #expect(key.first?.windowID == nil)
        #expect(key.first?.target == .focusless)
    }

    @Test
    func unregisterClearsKeyboardFocusForSurface() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 6)
        router.register(windowID: WindowID(rawValue: 60), surfaceID: 600)

        _ = router.route(rawKeyboardEnter(sequence: 1, seatID: seatID, surfaceID: 600))
        router.unregister(surfaceID: 600)
        let key = router.route(rawKeyboardKey(sequence: 2, seatID: seatID))

        #expect(key.first?.windowID == nil)
        #expect(key.first?.target == .focusless)
    }

    @Test
    func keyboardKeyAfterUnknownSurfaceEnterStaysUnmanagedSurface() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 18)

        let enter = router.route(rawKeyboardEnter(sequence: 1, seatID: seatID, surfaceID: 1_800))
        let key = router.route(rawKeyboardKey(sequence: 2, seatID: seatID))

        #expect(enter.first?.target == .unmanagedSurface)
        #expect(key.first?.windowID == nil)
        #expect(key.first?.target == .unmanagedSurface)
        #expect(
            key.first?.kind
                == .keyboard(
                    .raw(
                        .key(
                            KeyboardKeyEvent(
                                serial: 2,
                                time: 3,
                                rawKeycode: 4,
                                state: .pressed
                            )
                        )
                    )
                ))
    }
}

@Suite
struct KeyboardSeatLevelInputRouterTests {
    @Test
    func keymapRemainsSeatLevel() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 4)
        router.register(windowID: WindowID(rawValue: 50), surfaceID: 500)

        let keymap = router.route(rawKeyboardKeymap(sequence: 1, seatID: seatID))

        #expect(keymap.first?.windowID == nil)
        #expect(keymap.first?.target == .display)
        #expect(
            keymap.first?.kind
                == .keyboard(
                    .raw(.keymapChanged(KeyboardKeymapInfo(format: .xkbV1, size: 8)))
                ))
    }

    @Test
    func modifiersRemainSeatLevel() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 4)
        router.register(windowID: WindowID(rawValue: 50), surfaceID: 500)

        let modifiers = router.route(
            rawKeyboardModifiers(sequence: 2, seatID: seatID)
        )

        #expect(modifiers.first?.windowID == nil)
        #expect(modifiers.first?.target == .display)
        #expect(
            modifiers.first?.kind
                == .keyboard(
                    .raw(
                        .modifiers(
                            KeyboardModifiers(
                                serial: 2,
                                depressed: 3,
                                latched: 4,
                                locked: 5,
                                group: 6
                            )
                        )
                    )
                ))
    }

    @Test
    func repeatInfoRemainsSeatLevel() throws {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 4)
        router.register(windowID: WindowID(rawValue: 50), surfaceID: 500)

        let repeatInfo = try router.route(
            rawKeyboardRepeatInfo(sequence: 3, seatID: seatID, rate: 30, delay: 400))

        #expect(repeatInfo.first?.windowID == nil)
        #expect(repeatInfo.first?.target == .display)
        #expect(
            repeatInfo.first?.kind
                == .keyboard(
                    .raw(.repeatInfo(try KeyboardRepeatPolicy(rate: 30, delay: 400)))
                ))
    }
}

@Suite
struct SeatInputRouterTests {
    @Test
    func seatEventsRouteAtDisplayLevel() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 7)

        let changed = router.route(
            rawSeatChanged(sequence: 1, seatID: seatID, name: "seat0")
        )
        let removed = router.route(
            rawEvent(sequence: 2, seatID: seatID, kind: .seatRemoved)
        )

        #expect(changed.first?.windowID == nil)
        #expect(
            changed.first?.kind
                == .seat(
                    .changed(
                        SeatStateSnapshot(
                            uncheckedAdvertisedCapabilities: [.pointer],
                            activeCapabilities: [.pointer],
                            name: SeatName(rawValue: "seat0")
                        )
                    )
                ))
        #expect(removed.first?.windowID == nil)
        #expect(removed.first?.kind == .seat(.removed))
    }

    @Test
    func diagnosticsRouteAtDisplayLevel() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 77)
        let keymapID = RawKeyboardKeymapID(
            seatID: seatID,
            keyboardGeneration: 1,
            keymapGeneration: 1
        )

        let routed = router.route(
            rawEvent(
                sequence: 1,
                seatID: seatID,
                kind: .diagnostic(
                    RawInputDiagnostic(
                        .keymap(
                            .readFailed(
                                id: keymapID,
                                error: .missingNULTerminator(size: 12)
                            )
                        )
                    )
                )
            )
        )

        #expect(routed.first?.windowID == nil)
        #expect(
            routed.first?.kind
                == .diagnostic(
                    InputDiagnostic(
                        .keymap(.readFailed(.missingNULTerminator(size: 12)))
                    )
                ))
    }

    @Test
    func keyboardRepeatDiagnosticsRouteAtDisplayLevel() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 78)

        let routed = router.route(
            rawEvent(
                sequence: 1,
                seatID: seatID,
                kind: .diagnostic(
                    RawInputDiagnostic(
                        .keyboardRepeat(
                            RawKeyboardRepeatDiagnostic(
                                error: .negativeRate(rate: -1, delay: 400)
                            )
                        )
                    )
                )
            )
        )

        #expect(routed.first?.windowID == nil)
        #expect(
            routed.first?.kind
                == .diagnostic(
                    InputDiagnostic(
                        .keyboardRepeat(
                            KeyboardRepeatDiagnostic(
                                .negativeRate(rate: -1, delay: 400)
                            )
                        )
                    )
                ))
    }

    @Test
    func seatBindingDiagnosticsRouteWithTypedFailure() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 80)

        let routed = router.route(
            rawEvent(
                sequence: 1,
                seatID: seatID,
                kind: .diagnostic(
                    RawInputDiagnostic(
                        .seatBinding(
                            RawSeatBindingDiagnostic(
                                interface: "wl_keyboard",
                                failure: .listener(.keyboard)
                            )
                        )
                    )
                )
            )
        )

        #expect(routed.first?.windowID == nil)
        #expect(
            routed.first?.kind
                == .diagnostic(
                    InputDiagnostic(
                        .seatBinding(
                            InputSeatBindingDiagnostic(
                                interface: "wl_keyboard",
                                failure: .listener(.keyboard)
                            )
                        )
                    )
                ))
    }

    @Test
    func inputPipelineOverflowDiagnosticsRouteAtDisplayLevel() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 79)
        let rawOverflow = RawInputPipelineOverflow(
            stage: .rawInputQueue,
            capacity: RawInputQueueCapacity(unchecked: 4)
        )
        let overflow = InputPipelineOverflow(
            stage: .rawInputQueue,
            capacity: InputPipelineCapacity(unchecked: 4)
        )

        let routed = router.route(
            rawEvent(
                sequence: 1,
                seatID: seatID,
                kind: .diagnostic(
                    RawInputDiagnostic(
                        .inputPipelineOverflow(rawOverflow)
                    )
                )
            )
        )

        #expect(routed.first?.windowID == nil)
        #expect(
            routed.first?.kind
                == .diagnostic(
                    InputDiagnostic(
                        .inputPipelineOverflow(overflow)
                    )
                ))
    }

    @Test
    func seatRemovalClearsFocusedSurfacesForSeat() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 10)
        router.register(windowID: WindowID(rawValue: 100), surfaceID: 1_000)

        _ = router.route(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 1_000))
        _ = router.route(rawKeyboardEnter(sequence: 2, seatID: seatID, surfaceID: 1_000))
        _ = router.route(rawEvent(sequence: 3, seatID: seatID, kind: .seatRemoved))

        let motion = router.route(rawPointerMotion(sequence: 4, seatID: seatID, time: 4))
        let key = router.route(rawKeyboardKey(sequence: 5, seatID: seatID))

        #expect(motion.first?.windowID == nil)
        #expect(motion.first?.target == .focusless)
        #expect(key.first?.windowID == nil)
        #expect(key.first?.target == .focusless)
    }
}
