import CXKBCommonSystem
import Foundation
import WaylandRaw

public enum KeyboardInterpretationError: Error, Equatable, Sendable, CustomStringConvertible {
    case unsupportedKeymapFormat(UInt32)
    case invalidKeymapEncoding
    case keymapCreationFailed
    case stateCreationFailed
    case nonKeyboardInputDevice(RawInputDeviceID)
    case mismatchedKeyboardDevice(expected: RawInputDeviceID, actual: RawInputDeviceID)

    public var description: String {
        switch self {
        case .unsupportedKeymapFormat(let format):
            "Unsupported keyboard keymap format \(format)"
        case .invalidKeymapEncoding:
            "Keyboard keymap is not valid UTF-8 text"
        case .keymapCreationFailed:
            "xkbcommon failed to create a keymap"
        case .stateCreationFailed:
            "xkbcommon failed to create keyboard state"
        case .nonKeyboardInputDevice(let deviceID):
            "Keyboard interpreter received non-keyboard input device \(deviceID)"
        case .mismatchedKeyboardDevice(let expected, let actual):
            "Keyboard interpreter expected \(expected) but received \(actual)"
        }
    }
}

public struct InterpretedKeyEvent: Equatable, Sendable {
    public let serial: UInt32
    public let time: UInt32
    public let evdevKeycode: UInt32
    public let xkbKeycode: UInt32
    public let state: RawKeyboardKeyState
    public let keysym: UInt32
    public let keysymName: String?
    public let text: String?

    public init(
        serial eventSerial: UInt32,
        time eventTime: UInt32,
        evdevKeycode eventEvdevKeycode: UInt32,
        xkbKeycode eventXKBKeycode: UInt32,
        state eventState: RawKeyboardKeyState,
        keysym eventKeysym: UInt32,
        keysymName eventKeysymName: String?,
        text eventText: String?
    ) {
        serial = eventSerial
        time = eventTime
        evdevKeycode = eventEvdevKeycode
        xkbKeycode = eventXKBKeycode
        state = eventState
        keysym = eventKeysym
        keysymName = eventKeysymName
        text = eventText
    }
}

public final class KeyboardLayoutState {
    private static let evdevToXKBOffset: UInt32 = 8

    private let keymapID: RawKeyboardKeymapID
    private let context: OpaquePointer
    private let keymap: OpaquePointer
    private let state: OpaquePointer
    private let threadAffinity = ThreadAffinity()

    public init(keymap payload: RawKeyboardKeymapPayload) throws(KeyboardInterpretationError) {
        guard payload.format == .xkbV1 else {
            throw .unsupportedKeymapFormat(payload.format.rawValue)
        }

        guard let keymapText = String(bytes: payload.bytes, encoding: .utf8) else {
            throw .invalidKeymapEncoding
        }

        guard let newContext = xkb_context_new(XKB_CONTEXT_NO_FLAGS) else {
            throw .keymapCreationFailed
        }

        guard
            let newKeymap = keymapText.withCString({ textPointer in
                xkb_keymap_new_from_string(
                    newContext,
                    textPointer,
                    XKB_KEYMAP_FORMAT_TEXT_V1,
                    XKB_KEYMAP_COMPILE_NO_FLAGS
                )
            })
        else {
            xkb_context_unref(newContext)
            throw .keymapCreationFailed
        }

        guard let newState = xkb_state_new(newKeymap) else {
            xkb_keymap_unref(newKeymap)
            xkb_context_unref(newContext)
            throw .stateCreationFailed
        }

        keymapID = payload.id
        context = newContext
        keymap = newKeymap
        state = newState
    }

    public var id: RawKeyboardKeymapID {
        threadAffinity.preconditionIsOwnerThread()
        return keymapID
    }

    public func applyModifiers(_ modifiers: RawKeyboardModifiers) {
        threadAffinity.preconditionIsOwnerThread()

        _ = xkb_state_update_mask(
            state,
            modifiers.depressed,
            modifiers.latched,
            modifiers.locked,
            0,
            0,
            modifiers.group
        )
    }

    public func modifierMask(named name: String) -> UInt32? {
        threadAffinity.preconditionIsOwnerThread()

        return name.withCString { namePointer -> UInt32? in
            let index = xkb_keymap_mod_get_index(keymap, namePointer)
            guard index != XKB_MOD_INVALID, index < UInt32.bitWidth else {
                return nil
            }

            return UInt32(1) << index
        }
    }

    public func interpret(_ key: RawKeyboardKey) -> InterpretedKeyEvent {
        threadAffinity.preconditionIsOwnerThread()

        let xkbKeycode = key.evdevKeycode + Self.evdevToXKBOffset

        let keysym = xkb_state_key_get_one_sym(state, xkbKeycode)
        return InterpretedKeyEvent(
            serial: key.serial,
            time: key.time,
            evdevKeycode: key.evdevKeycode,
            xkbKeycode: xkbKeycode,
            state: key.state,
            keysym: keysym,
            keysymName: keysymName(for: keysym),
            text: utf8Text(for: xkbKeycode)
        )
    }

    deinit {
        threadAffinity.preconditionIsOwnerThread()
        xkb_state_unref(state)
        xkb_keymap_unref(keymap)
        xkb_context_unref(context)
    }

    private func keysymName(for keysym: UInt32) -> String? {
        var buffer = [CChar](repeating: 0, count: 128)
        let result = xkb_keysym_get_name(keysym, &buffer, buffer.count)
        guard result > 0 else { return nil }

        return stringFromNullTerminatedBuffer(buffer)
    }

    private func utf8Text(for xkbKeycode: UInt32) -> String? {
        var buffer = [CChar](repeating: 0, count: 128)
        let result = xkb_state_key_get_utf8(state, xkbKeycode, &buffer, buffer.count)
        guard result > 0 else { return nil }

        return stringFromNullTerminatedBuffer(buffer)
    }

    private func stringFromNullTerminatedBuffer(_ buffer: [CChar]) -> String {
        let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
        return String(
            bytes: buffer[..<endIndex].map { UInt8(bitPattern: $0) },
            encoding: .utf8
        ) ?? ""
    }
}
