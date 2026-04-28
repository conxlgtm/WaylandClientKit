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

func interpreterWithFixtureKeymap() throws -> KeyboardInterpreter {
    let interpreter = try KeyboardInterpreter()
    let deviceID = keyboardDevice()
    _ = interpreter.consume(
        rawKeyboardInputEvent(
            deviceID: deviceID,
            kind: .keymap(keymapPayload(text: try fixtureKeymapText()))
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
) -> RawKeyboardKeymapPayload {
    RawKeyboardKeymapPayload(
        id: RawKeyboardKeymapID(
            seatID: seatID,
            keyboardGeneration: keyboardGeneration,
            keymapGeneration: keymapGeneration
        ),
        format: format,
        size: UInt32(bytes.count),
        bytes: bytes
    )
}

func keymapPayload(
    text: String,
    seatID: RawSeatID = RawSeatID(rawValue: 1),
    keyboardGeneration: UInt64 = 1,
    keymapGeneration: UInt64 = 1
) -> RawKeyboardKeymapPayload {
    keymapPayload(
        bytes: Array(text.utf8),
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
