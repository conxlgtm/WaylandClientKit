import WaylandRaw

func rawPointerEnter(
    sequence: UInt64,
    seatID: RawSeatID,
    surfaceID: RawObjectID?,
    serial: UInt32 = 1,
    xRaw: Int32 = 0,
    yRaw: Int32 = 0
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
        )
    )
}

func rawPointerLeave(
    sequence: UInt64,
    seatID: RawSeatID,
    surfaceID: RawObjectID?,
    serial: UInt32 = 1
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .pointer(.leave(RawPointerLeave(serial: serial, surfaceID: surfaceID)))
    )
}

func rawPointerMotion(
    sequence: UInt64,
    seatID: RawSeatID,
    time: UInt32,
    xRaw: Int32 = 0,
    yRaw: Int32 = 0
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
        )
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
    pressedKeys: [UInt32] = []
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
        )
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
    rawKeycode: UInt32 = 4
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
        )
    )
}

func rawKeyboardKeymap(sequence: UInt64, seatID: RawSeatID) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .keyboard(
            .keymap(
                RawKeyboardKeymapPayload(
                    id: RawKeyboardKeymapID(
                        seatID: seatID,
                        keyboardGeneration: 1,
                        keymapGeneration: 1
                    ),
                    format: .xkbV1,
                    size: 8,
                    bytes: [1, 2, 3]
                )
            )
        )
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
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .keyboard(.repeatInfo(RawKeyboardRepeatInfo(rate: rate, delay: delay)))
    )
}

func rawSeatChanged(sequence: UInt64, seatID: RawSeatID, name: String) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .seat(
            RawSeatEventSnapshot(
                advertisedCapabilities: [.pointer],
                activeCapabilities: [.pointer],
                name: name
            )
        )
    )
}

func rawEvent(
    sequence: UInt64,
    seatID: RawSeatID,
    kind: RawInputEventKind
) -> RawInputEvent {
    RawInputEvent(
        sequence: sequence,
        seatID: seatID,
        deviceID: nil,
        kind: kind
    )
}
