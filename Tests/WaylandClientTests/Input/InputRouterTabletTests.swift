import Testing
import WaylandRaw

@testable import WaylandClient

// swiftlint:disable type_body_length function_body_length
@Suite
struct TabletInputRouterTests {
    @Test
    func proximityInTargetsSurfaceAndMotionRoutesToFocusedWindow() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 71)
        let windowID = WindowID(rawValue: 710)
        let surfaceID: RawObjectID = 7_100
        let tool = RawTabletToolIdentity(objectID: RawObjectID(9_001))
        let tablet = RawTabletIdentity(objectID: RawObjectID(9_002))
        router.register(windowID: windowID, surfaceID: surfaceID)

        let proximity = router.route(
            rawTabletEvent(
                sequence: 1,
                seatID: seatID,
                .tool(
                    .proximityIn(
                        RawTabletToolProximityIn(
                            tool: tool,
                            serial: 42,
                            tablet: tablet,
                            surfaceID: surfaceID
                        )
                    )
                )
            )
        )
        let motion = router.route(
            rawTabletEvent(
                sequence: 2,
                seatID: seatID,
                .tool(
                    .motion(
                        tool,
                        x: WaylandFixed(rawValue: 256),
                        y: WaylandFixed(rawValue: 512)
                    )
                )
            )
        )

        #expect(proximity.first?.windowID == windowID)
        #expect(
            proximity.first?.kind
                == .tablet(
                    .tool(
                        .proximityIn(
                            TabletToolProximityIn(
                                tool: TabletToolID(tool),
                                serial: InputSerial(rawValue: 42),
                                tablet: TabletID(tablet)
                            )
                        )
                    )
                )
        )
        #expect(motion.first?.windowID == windowID)
        #expect(
            motion.first?.kind
                == .tablet(.tool(.motion(TabletToolID(tool), PointerLocation(x: 1, y: 2))))
        )
    }

    @Test
    func toolFactsPreservePressureTiltButtonsFrameAndUnknownCapabilities() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 72)
        let tool = RawTabletToolIdentity(objectID: RawObjectID(9_101))

        let capability = router.route(
            rawTabletEvent(
                sequence: 1,
                seatID: seatID,
                .tool(.capability(tool, RawTabletToolCapability(rawValue: 99)))
            )
        )
        let pressure = router.route(
            rawTabletEvent(sequence: 2, seatID: seatID, .tool(.pressure(tool, 4_096)))
        )
        let tilt = router.route(
            rawTabletEvent(
                sequence: 3,
                seatID: seatID,
                .tool(
                    .tilt(
                        tool,
                        x: WaylandFixed(rawValue: 128),
                        y: WaylandFixed(rawValue: -256)
                    )
                )
            )
        )
        let button = router.route(
            rawTabletEvent(
                sequence: 4,
                seatID: seatID,
                .tool(
                    .button(
                        RawTabletToolButton(
                            tool: tool,
                            serial: 7,
                            button: 331,
                            state: .pressed
                        )
                    )
                )
            )
        )
        let frame = router.route(
            rawTabletEvent(sequence: 5, seatID: seatID, .tool(.frame(tool, time: 123)))
        )

        #expect(
            capability.first?.kind
                == .tablet(
                    .tool(.capability(TabletToolID(tool), .unknown(99)))
                )
        )
        #expect(pressure.first?.kind == .tablet(.tool(.pressure(TabletToolID(tool), 4_096))))
        #expect(
            tilt.first?.kind
                == .tablet(.tool(.tilt(TabletToolID(tool), x: 0.5, y: -1.0)))
        )
        #expect(
            button.first?.kind
                == .tablet(
                    .tool(
                        .button(
                            TabletToolButton(
                                tool: TabletToolID(tool),
                                serial: InputSerial(rawValue: 7),
                                button: PointerButtonCode(rawValue: 331),
                                state: .pressed
                            )
                        )
                    )
                )
        )
        #expect(
            frame.first?.kind
                == .tablet(
                    .tool(
                        .frame(
                            TabletToolID(tool),
                            time: WaylandTimestampMilliseconds(rawValue: 123)
                        )
                    )
                )
        )
    }

    @Test
    func padEnterTargetsSurfaceAndLeaveClearsFocus() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 73)
        let windowID = WindowID(rawValue: 730)
        let surfaceID: RawObjectID = 7_300
        let pad = RawTabletPadIdentity(objectID: RawObjectID(9_201))
        let tablet = RawTabletIdentity(objectID: RawObjectID(9_202))
        router.register(windowID: windowID, surfaceID: surfaceID)

        let enter = router.route(
            rawTabletEvent(
                sequence: 1,
                seatID: seatID,
                .pad(
                    .enter(
                        RawTabletPadEnter(
                            pad: pad,
                            serial: 77,
                            tablet: tablet,
                            surfaceID: surfaceID
                        )
                    )
                )
            )
        )
        let button = router.route(
            rawTabletEvent(
                sequence: 2,
                seatID: seatID,
                .pad(
                    .button(
                        RawTabletPadButton(
                            pad: pad,
                            time: 10,
                            button: 3,
                            state: .released
                        )
                    )
                )
            )
        )
        let leave = router.route(
            rawTabletEvent(
                sequence: 3,
                seatID: seatID,
                .pad(.leave(RawTabletPadLeave(pad: pad, serial: 78, surfaceID: surfaceID)))
            )
        )
        let lateButton = router.route(
            rawTabletEvent(
                sequence: 4,
                seatID: seatID,
                .pad(
                    .button(
                        RawTabletPadButton(
                            pad: pad,
                            time: 11,
                            button: 4,
                            state: .pressed
                        )
                    )
                )
            )
        )

        #expect(enter.first?.windowID == windowID)
        #expect(button.first?.windowID == windowID)
        #expect(leave.first?.windowID == windowID)
        #expect(lateButton.first?.target == .focusless)
    }

    @Test
    func unregisterAndSeatRemovalClearTabletFocus() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 74)
        let windowID = WindowID(rawValue: 740)
        let surfaceID: RawObjectID = 7_400
        let retainedSurfaceID: RawObjectID = 7_401
        let tool = RawTabletToolIdentity(objectID: RawObjectID(9_301))
        let tablet = RawTabletIdentity(objectID: RawObjectID(9_302))
        router.register(windowID: windowID, surfaceID: surfaceID)
        router.register(windowID: WindowID(rawValue: 741), surfaceID: retainedSurfaceID)

        _ = router.route(
            rawTabletEvent(
                sequence: 1,
                seatID: seatID,
                .tool(
                    .proximityIn(
                        RawTabletToolProximityIn(
                            tool: tool,
                            serial: 1,
                            tablet: tablet,
                            surfaceID: surfaceID
                        )
                    )
                )
            )
        )
        router.unregister(surfaceID: surfaceID)
        let afterUnregister = router.route(
            rawTabletEvent(sequence: 2, seatID: seatID, .tool(.pressure(tool, 1)))
        )
        _ = router.route(
            rawTabletEvent(
                sequence: 3,
                seatID: seatID,
                .tool(
                    .proximityIn(
                        RawTabletToolProximityIn(
                            tool: tool,
                            serial: 2,
                            tablet: tablet,
                            surfaceID: retainedSurfaceID
                        )
                    )
                )
            )
        )
        _ = router.route(rawEvent(sequence: 4, seatID: seatID, kind: .seatRemoved))
        let afterSeatRemoval = router.route(
            rawTabletEvent(sequence: 5, seatID: seatID, .tool(.pressure(tool, 2)))
        )

        #expect(afterUnregister.first?.target == .focusless)
        #expect(afterSeatRemoval.first?.target == .focusless)
    }

    @Test
    func deviceFactsRouteAsDisplayEventsAndPreserveUnknownBus() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 75)
        let tablet = RawTabletIdentity(objectID: RawObjectID(9_401))

        let added = router.route(
            rawTabletEvent(sequence: 1, seatID: seatID, .tabletAdded(tablet))
        )
        let bus = router.route(
            rawTabletEvent(
                sequence: 2,
                seatID: seatID,
                .tablet(.busType(tablet, RawTabletBusType(rawValue: 999)))
            )
        )

        #expect(added.first?.target == .display)
        #expect(added.first?.kind == .tablet(.tabletAdded(TabletID(tablet))))
        #expect(bus.first?.target == .display)
        #expect(
            bus.first?.kind
                == .tablet(.tablet(.busType(TabletID(tablet), .unknown(999))))
        )
    }
}
// swiftlint:enable type_body_length function_body_length

private func rawTabletEvent(
    sequence: UInt64,
    seatID: RawSeatID,
    _ event: RawTabletEvent
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .tablet(event),
        deviceID: RawInputDeviceID(seatID: seatID, kind: .tablet, generation: 1)
    )
}
