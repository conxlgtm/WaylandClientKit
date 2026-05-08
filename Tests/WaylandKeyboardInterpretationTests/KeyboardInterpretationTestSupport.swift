import Foundation
import WaylandRaw

@testable import WaylandKeyboardInterpretation

enum KeyboardInterpretationTestFixtureError: Error {
    case missingKeymapFixture
}

extension InterpretedKeyboardEvent {
    var interpretedKey: InterpretedKeyboardKey? {
        if case .key(let key) = kind {
            return key
        }

        return nil
    }

    var interpretedModifiers: InterpretedKeyboardModifiers? {
        if case .modifiers(let modifiers) = kind {
            return modifiers
        }

        return nil
    }
}

func unavailable(
    _ reason: KeyboardInterpretationUnavailableReason
) -> InterpretedKeyboardEventKind {
    .unavailable(KeyboardInterpretationUnavailable(reason: reason))
}

func requireSendable<T: Sendable>(_ type: T.Type) {
    _ = type
}

func interpreterWithFixtureKeymap(
    configuration: KeyboardInterpreterConfiguration = .init()
) throws -> KeyboardInterpreter {
    let interpreter = try KeyboardInterpreter(configuration: configuration)
    let deviceID = keyboardDevice()
    _ = interpreter.consume(
        rawKeyboardInputEvent(
            deviceID: deviceID,
            kind: .keymap(try keymapPayload(text: try fixtureKeymapText()))
        )
    )
    return interpreter
}

func keymapPayload(
    bytes: [UInt8],
    format: RawKeyboardKeymapFormat = .xkbV1,
    seatID: RawSeatID = RawSeatID(rawValue: 1),
    keyboardGeneration: UInt64 = 1,
    keymapGeneration: UInt64 = 1
) throws -> RawKeyboardKeymapPayload {
    let id = RawKeyboardKeymapID(
        seatID: seatID,
        keyboardGeneration: keyboardGeneration,
        keymapGeneration: keymapGeneration
    )

    if format == .noKeymap {
        return .noKeymap(id: id)
    }

    return try .xkbV1(
        id: id,
        bytes: bytes
    )
}

func keymapPayload(
    text: String,
    seatID: RawSeatID = RawSeatID(rawValue: 1),
    keyboardGeneration: UInt64 = 1,
    keymapGeneration: UInt64 = 1
) throws -> RawKeyboardKeymapPayload {
    try keymapPayload(
        bytes: Array(text.utf8) + [0],
        seatID: seatID,
        keyboardGeneration: keyboardGeneration,
        keymapGeneration: keymapGeneration
    )
}

func keyboardDevice(
    seatRawValue: UInt32 = 1,
    generation: UInt64 = 1
) -> RawInputDeviceID {
    RawInputDeviceID(
        seatID: RawSeatID(rawValue: seatRawValue),
        kind: .keyboard,
        generation: generation
    )
}

func rawKeyboardInputEvent(
    deviceID: RawInputDeviceID,
    kind: RawKeyboardEvent,
    sequence: UInt64 = 1
) -> RawInputEvent {
    RawInputEvent(
        sequence: sequence,
        seatID: deviceID.seatID,
        deviceID: deviceID,
        kind: .keyboard(kind)
    )
}

func qKey(
    evdevKeycode: UInt32 = 16,
    state: RawKeyboardKeyState = .pressed
) -> RawKeyboardKey {
    RawKeyboardKey(
        serial: 2,
        time: 3,
        evdevKeycode: evdevKeycode,
        state: state
    )
}

func deadAcuteKey(state: RawKeyboardKeyState = .pressed) -> RawKeyboardKey {
    qKey(evdevKeycode: 2, state: state)
}

func aKey(state: RawKeyboardKeyState = .pressed) -> RawKeyboardKey {
    qKey(evdevKeycode: 30, state: state)
}

func bKey(state: RawKeyboardKeyState = .pressed) -> RawKeyboardKey {
    qKey(evdevKeycode: 48, state: state)
}

func shiftKey(state: RawKeyboardKeyState = .pressed) -> RawKeyboardKey {
    qKey(evdevKeycode: 42, state: state)
}

func composeTableText() -> String {
    """
    <dead_acute> <a> : "á" aacute
    <dead_acute> <A> : "Á" Aacute
    """
}

func multiStepComposeTableText() -> String {
    """
    <dead_acute> <b> <a> : "x" X
    """
}

func fixtureKeymapText() throws -> String {
    guard
        let fileURL = Bundle.module.url(
            forResource: "us-keymap",
            withExtension: "xkb",
            subdirectory: "Fixtures"
        )
    else {
        throw KeyboardInterpretationTestFixtureError.missingKeymapFixture
    }

    return try String(contentsOf: fileURL, encoding: .utf8)
}
