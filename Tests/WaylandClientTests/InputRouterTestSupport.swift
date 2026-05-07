import WaylandKeyboardInterpretation
import WaylandRaw

func rawPointerEnter(
    sequence: UInt64,
    seatID: RawSeatID,
    surfaceID: RawObjectID?,
    serial: UInt32 = 1,
    xRaw: Int32 = 0,
    yRaw: Int32 = 0,
    deviceID: RawInputDeviceID? = nil
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .pointer(
            .enter(
                RawPointerEnter(
                    serial: serial,
                    surfaceID: surfaceID,
                    x: WaylandFixed(rawValue: xRaw),
                    y: WaylandFixed(rawValue: yRaw)
                )
            )
        ),
        deviceID: deviceID
    )
}

func rawPointerLeave(
    sequence: UInt64,
    seatID: RawSeatID,
    surfaceID: RawObjectID?,
    serial: UInt32 = 1,
    deviceID: RawInputDeviceID? = nil
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .pointer(.leave(RawPointerLeave(serial: serial, surfaceID: surfaceID))),
        deviceID: deviceID
    )
}

func rawPointerMotion(
    sequence: UInt64,
    seatID: RawSeatID,
    time: UInt32,
    xRaw: Int32 = 0,
    yRaw: Int32 = 0,
    deviceID: RawInputDeviceID? = nil
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .pointer(
            .motion(
                RawPointerMotion(
                    time: time,
                    x: WaylandFixed(rawValue: xRaw),
                    y: WaylandFixed(rawValue: yRaw)
                )
            )
        ),
        deviceID: deviceID
    )
}

func rawPointerButton(
    sequence: UInt64,
    seatID: RawSeatID
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .pointer(
            .button(
                RawPointerButton(
                    serial: 2,
                    time: 3,
                    button: 272,
                    state: .pressed
                )
            )
        )
    )
}

func rawPointerAxis(
    sequence: UInt64,
    seatID: RawSeatID
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .pointer(
            .axis(
                .axis(
                    time: 4,
                    axis: .verticalScroll,
                    value: WaylandFixed(rawValue: 512)
                )
            )
        )
    )
}

func rawKeyboardEnter(
    sequence: UInt64,
    seatID: RawSeatID,
    surfaceID: RawObjectID?,
    serial: UInt32 = 1,
    pressedKeys: [UInt32] = [],
    deviceID: RawInputDeviceID? = nil
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .keyboard(
            .enter(
                RawKeyboardEnter(
                    serial: serial,
                    surfaceID: surfaceID,
                    pressedKeys: pressedKeys
                )
            )
        ),
        deviceID: deviceID
    )
}

func rawKeyboardLeave(
    sequence: UInt64,
    seatID: RawSeatID,
    surfaceID: RawObjectID?
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .keyboard(.leave(RawKeyboardLeave(serial: 2, surfaceID: surfaceID)))
    )
}

func rawKeyboardKey(
    sequence: UInt64,
    seatID: RawSeatID,
    serial: UInt32 = 2,
    time: UInt32 = 3,
    rawKeycode: UInt32 = 4,
    deviceID: RawInputDeviceID? = nil
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .keyboard(
            .key(
                RawKeyboardKey(
                    serial: serial,
                    time: time,
                    evdevKeycode: rawKeycode,
                    state: .pressed
                )
            )
        ),
        deviceID: deviceID
    )
}

func rawKeyboardKeymap(
    sequence: UInt64,
    seatID: RawSeatID,
    deviceID: RawInputDeviceID? = nil
) -> RawInputEvent {
    let payload: RawKeyboardKeymapPayload
    do {
        payload = try .xkbV1(
            id: RawKeyboardKeymapID(
                seatID: seatID,
                keyboardGeneration: 1,
                keymapGeneration: 1
            ),
            bytes: [1, 2, 3, 4, 5, 6, 7, 0]
        )
    } catch {
        preconditionFailure("test keymap payload should be valid: \(error)")
    }

    return rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .keyboard(.keymap(payload)),
        deviceID: deviceID
    )
}

func rawKeyboardModifiers(
    sequence: UInt64,
    seatID: RawSeatID
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .keyboard(
            .modifiers(
                RawKeyboardModifiers(
                    serial: 2,
                    depressed: 3,
                    latched: 4,
                    locked: 5,
                    group: 6
                )
            )
        )
    )
}

func rawKeyboardRepeatInfo(
    sequence: UInt64,
    seatID: RawSeatID,
    rate: Int32,
    delay: Int32
) throws -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .keyboard(.repeatInfo(try RawKeyboardRepeatInfo(rate: rate, delay: delay)))
    )
}

func rawTouchDown(
    sequence: UInt64,
    seatID: RawSeatID,
    surfaceID: RawObjectID?,
    serial: UInt32 = 1,
    time: UInt32 = 2,
    id: RawTouchID = 3,
    xRaw: Int32 = 0,
    yRaw: Int32 = 0,
    deviceID: RawInputDeviceID? = nil
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .touch(
            .down(
                RawTouchDown(
                    serial: serial,
                    time: time,
                    surfaceID: surfaceID,
                    id: id,
                    x: WaylandFixed(rawValue: xRaw),
                    y: WaylandFixed(rawValue: yRaw)
                )
            )
        ),
        deviceID: deviceID
    )
}

func rawTouchUp(
    sequence: UInt64,
    seatID: RawSeatID,
    serial: UInt32 = 4,
    time: UInt32 = 5,
    id: RawTouchID = 3
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .touch(.up(RawTouchUp(serial: serial, time: time, id: id)))
    )
}

func rawTouchMotion(
    sequence: UInt64,
    seatID: RawSeatID,
    time: UInt32 = 6,
    id: RawTouchID = 3,
    xRaw: Int32 = 0,
    yRaw: Int32 = 0,
    deviceID: RawInputDeviceID? = nil
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .touch(
            .motion(
                RawTouchMotion(
                    time: time,
                    id: id,
                    x: WaylandFixed(rawValue: xRaw),
                    y: WaylandFixed(rawValue: yRaw)
                )
            )
        ),
        deviceID: deviceID
    )
}

func rawTouchShape(
    sequence: UInt64,
    seatID: RawSeatID,
    id: RawTouchID = 3,
    majorRaw: Int32 = 512,
    minorRaw: Int32 = 256
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .touch(
            .shape(
                RawTouchShape(
                    id: id,
                    major: WaylandFixed(rawValue: majorRaw),
                    minor: WaylandFixed(rawValue: minorRaw)
                )
            )
        )
    )
}

func rawTouchOrientation(
    sequence: UInt64,
    seatID: RawSeatID,
    id: RawTouchID = 3,
    orientationRaw: Int32 = 128
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .touch(
            .orientation(
                RawTouchOrientation(
                    id: id,
                    orientation: WaylandFixed(rawValue: orientationRaw)
                )
            )
        )
    )
}

func rawSeatChanged(
    sequence: UInt64,
    seatID: RawSeatID,
    name: String?,
    advertisedCapabilities: WaylandRaw.SeatCapabilities = [.pointer],
    activeCapabilities: WaylandRaw.SeatCapabilities = [.pointer]
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .seat(
            RawSeatEventSnapshot(
                advertisedCapabilities: advertisedCapabilities,
                activeCapabilities: activeCapabilities,
                name: name
            )
        )
    )
}

func rawEvent(
    sequence: UInt64,
    seatID: RawSeatID,
    kind: RawInputEventKind,
    deviceID: RawInputDeviceID? = nil
) -> RawInputEvent {
    RawInputEvent(
        sequence: sequence,
        seatID: seatID,
        deviceID: deviceID,
        kind: kind
    )
}

func interpretedKeyboardEvent(
    sequence: UInt64,
    seatID: RawSeatID,
    kind: WaylandKeyboardInterpretation.InterpretedKeyboardEventKind
) -> WaylandKeyboardInterpretation.InterpretedKeyboardEvent {
    WaylandKeyboardInterpretation.InterpretedKeyboardEvent(
        sequence: sequence,
        seatID: seatID,
        deviceID: RawInputDeviceID(seatID: seatID, kind: .keyboard, generation: 1),
        kind: kind
    )
}
