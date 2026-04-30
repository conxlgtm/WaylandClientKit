import CXKBCommonSystem
import Foundation
import WaylandRaw

package enum KeyboardInterpreterError: Error, Equatable, Sendable, CustomStringConvertible {
    case contextCreationFailed

    package var description: String {
        switch self {
        case .contextCreationFailed:
            "xkbcommon failed to create a context"
        }
    }
}

enum KeyboardLayoutError: Error, Equatable, Sendable, CustomStringConvertible {
    case contextCreationFailed
    case unsupportedKeymapFormat(UInt32)
    case emptyKeymap
    case invalidKeymap
    case stateCreationFailed
    case invalidKeycode(UInt32)

    var description: String {
        switch self {
        case .contextCreationFailed:
            "xkbcommon failed to create a context"
        case .unsupportedKeymapFormat(let format):
            "Unsupported keyboard keymap format \(format)"
        case .emptyKeymap:
            "Keyboard keymap payload is empty"
        case .invalidKeymap:
            "xkbcommon failed to create a keymap"
        case .stateCreationFailed:
            "xkbcommon failed to create keyboard state"
        case .invalidKeycode(let keycode):
            "Keyboard keycode \(keycode) cannot be converted to an XKB keycode"
        }
    }
}

package struct InterpretedKeyboardEvent: Equatable, Sendable {
    package let sequence: UInt64
    package let seatID: RawSeatID
    package let deviceID: RawInputDeviceID?
    package let kind: InterpretedKeyboardEventKind

    package init(
        sequence eventSequence: UInt64,
        seatID eventSeatID: RawSeatID,
        deviceID eventDeviceID: RawInputDeviceID?,
        kind eventKind: InterpretedKeyboardEventKind
    ) {
        sequence = eventSequence
        seatID = eventSeatID
        deviceID = eventDeviceID
        kind = eventKind
    }
}

package enum InterpretedKeyboardEventKind: Equatable, Sendable {
    case keymap(InterpretedKeyboardKeymap)
    case key(InterpretedKeyboardKey)
    case modifiers(InterpretedKeyboardModifiers)
    case repeatInfo(InterpretedKeyboardRepeatInfo)
    case unavailable(KeyboardInterpretationUnavailable)
}

package struct InterpretedKeyboardKeymap: Equatable, Sendable {
    package let id: RawKeyboardKeymapID
    package let format: RawKeyboardKeymapFormat
    package let size: UInt32

    package init(
        id keymapID: RawKeyboardKeymapID,
        format keymapFormat: RawKeyboardKeymapFormat,
        size keymapSize: UInt32
    ) {
        id = keymapID
        format = keymapFormat
        size = keymapSize
    }
}

package struct InterpretedKeyboardKey: Equatable, Sendable {
    package let serial: UInt32
    package let time: UInt32
    package let evdevKeycode: UInt32
    package let xkbKeycode: UInt32
    package let state: InterpretedKeyboardKeyState
    package let keysym: KeyboardKeysym
    package let keysymName: String?
    package let utf8: String?
    package let repeats: Bool

    package init(
        serial eventSerial: UInt32,
        time eventTime: UInt32,
        evdevKeycode eventEvdevKeycode: UInt32,
        xkbKeycode eventXKBKeycode: UInt32,
        state eventState: InterpretedKeyboardKeyState,
        keysym eventKeysym: KeyboardKeysym,
        keysymName eventKeysymName: String?,
        utf8 eventUTF8: String?,
        repeats eventRepeats: Bool
    ) {
        serial = eventSerial
        time = eventTime
        evdevKeycode = eventEvdevKeycode
        xkbKeycode = eventXKBKeycode
        state = eventState
        keysym = eventKeysym
        keysymName = eventKeysymName
        utf8 = eventUTF8
        repeats = eventRepeats
    }
}

package struct InterpretedKeyboardKeyState: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue stateRawValue: UInt32) {
        rawValue = stateRawValue
    }

    package static let released = Self(rawValue: 0)
    package static let pressed = Self(rawValue: 1)
    package static let repeated = Self(rawValue: 2)
}

package struct KeyboardKeysym: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue keysymRawValue: UInt32) {
        rawValue = keysymRawValue
    }
}

package struct InterpretedKeyboardModifiers: Equatable, Sendable {
    package let serial: UInt32
    package let depressed: UInt32
    package let latched: UInt32
    package let locked: UInt32
    package let group: UInt32
    package let changedComponents: XKBStateComponents

    package init(
        serial eventSerial: UInt32,
        depressed eventDepressed: UInt32,
        latched eventLatched: UInt32,
        locked eventLocked: UInt32,
        group eventGroup: UInt32,
        changedComponents eventChangedComponents: XKBStateComponents
    ) {
        serial = eventSerial
        depressed = eventDepressed
        latched = eventLatched
        locked = eventLocked
        group = eventGroup
        changedComponents = eventChangedComponents
    }
}

package struct XKBStateComponents: OptionSet, Sendable {
    package let rawValue: UInt32

    package init(rawValue componentsRawValue: UInt32) {
        rawValue = componentsRawValue
    }

    package static let modsDepressed = Self(rawValue: 1 << 0)
    package static let modsLatched = Self(rawValue: 1 << 1)
    package static let modsLocked = Self(rawValue: 1 << 2)
    package static let modsEffective = Self(rawValue: 1 << 3)
    package static let layoutDepressed = Self(rawValue: 1 << 4)
    package static let layoutLatched = Self(rawValue: 1 << 5)
    package static let layoutLocked = Self(rawValue: 1 << 6)
    package static let layoutEffective = Self(rawValue: 1 << 7)
    package static let leds = Self(rawValue: 1 << 8)
}

package struct InterpretedKeyboardRepeatInfo: Equatable, Sendable {
    package let rate: Int32
    package let delay: Int32

    package init(rate repeatRate: Int32, delay repeatDelay: Int32) {
        rate = repeatRate
        delay = repeatDelay
    }
}

package struct KeyboardInterpretationUnavailable: Equatable, Sendable {
    package let reason: KeyboardInterpretationUnavailableReason

    package init(reason unavailableReason: KeyboardInterpretationUnavailableReason) {
        reason = unavailableReason
    }
}

package enum KeyboardInterpretationUnavailableReason: Equatable, Sendable {
    case missingDeviceID
    case unsupportedKeymapFormat(UInt32)
    case emptyKeymap
    case invalidKeymap
    case missingKeymap
    case missingKeyboardState
    case invalidKeycode(UInt32)
    case nonKeyboardInputDevice(RawInputDeviceID)
    case mismatchedKeyboardSeat(expected: RawSeatID, actual: RawSeatID)
    case mismatchedKeyboardDevice(expected: RawInputDeviceID, actual: RawInputDeviceID)
}

final class XKBContextOwner {
    let pointer: OpaquePointer

    init() throws(KeyboardLayoutError) {
        guard let newPointer = xkb_context_new(XKB_CONTEXT_NO_FLAGS) else {
            throw .contextCreationFailed
        }

        xkb_context_set_log_level(newPointer, XKB_LOG_LEVEL_CRITICAL)
        pointer = newPointer
    }

    deinit {
        xkb_context_unref(pointer)
    }
}

final class XKBKeymapOwner {
    let pointer: OpaquePointer

    init(context: XKBContextOwner, payload: RawKeyboardKeymapPayload)
        throws(KeyboardLayoutError)
    {
        guard payload.format == .xkbV1 else {
            throw .unsupportedKeymapFormat(payload.format.rawValue)
        }

        guard !payload.bytes.isEmpty else {
            throw .emptyKeymap
        }

        let newPointer = payload.bytes.withUnsafeBytes { rawBuffer -> OpaquePointer? in
            guard let baseAddress = rawBuffer.baseAddress else {
                return nil
            }

            return xkb_keymap_new_from_buffer(
                context.pointer,
                baseAddress.assumingMemoryBound(to: CChar.self),
                payload.bytes.count,
                XKB_KEYMAP_FORMAT_TEXT_V1,
                XKB_KEYMAP_COMPILE_NO_FLAGS
            )
        }

        guard let newPointer else {
            throw .invalidKeymap
        }

        pointer = newPointer
    }

    deinit {
        xkb_keymap_unref(pointer)
    }
}

final class XKBStateOwner {
    let pointer: OpaquePointer

    init(keymap: XKBKeymapOwner) throws(KeyboardLayoutError) {
        guard let newPointer = xkb_state_new(keymap.pointer) else {
            throw .stateCreationFailed
        }

        pointer = newPointer
    }

    deinit {
        xkb_state_unref(pointer)
    }
}

final class KeyboardLayoutState {
    private static let evdevToXKBOffset: UInt32 = 8

    private let keymapID: RawKeyboardKeymapID
    private let context: XKBContextOwner
    private let keymap: XKBKeymapOwner
    private let state: XKBStateOwner
    private let threadAffinity = ThreadAffinity()

    init(
        context sharedContext: XKBContextOwner,
        keymap payload: RawKeyboardKeymapPayload
    ) throws(KeyboardLayoutError) {
        keymapID = payload.id
        context = sharedContext
        keymap = try XKBKeymapOwner(context: sharedContext, payload: payload)
        state = try XKBStateOwner(keymap: keymap)
    }

    init(keymap payload: RawKeyboardKeymapPayload)
        throws(KeyboardLayoutError)
    {
        let newContext = try XKBContextOwner()
        keymapID = payload.id
        context = newContext
        keymap = try XKBKeymapOwner(context: newContext, payload: payload)
        state = try XKBStateOwner(keymap: keymap)
    }

    var id: RawKeyboardKeymapID {
        threadAffinity.preconditionIsOwnerThread()
        return keymapID
    }

    func applyModifiers(_ modifiers: RawKeyboardModifiers) -> XKBStateComponents {
        threadAffinity.preconditionIsOwnerThread()

        let changed = xkb_state_update_mask(
            state.pointer,
            modifiers.depressed,
            modifiers.latched,
            modifiers.locked,
            0,
            0,
            modifiers.group
        )
        return XKBStateComponents(rawValue: UInt32(changed.rawValue))
    }

    func modifierMask(named name: String) -> UInt32? {
        threadAffinity.preconditionIsOwnerThread()

        return name.withCString { namePointer -> UInt32? in
            let index = xkb_keymap_mod_get_index(keymap.pointer, namePointer)
            guard index != XKB_MOD_INVALID, index < UInt32.bitWidth else {
                return nil
            }

            return UInt32(1) << index
        }
    }

    func interpret(_ key: RawKeyboardKey) throws(KeyboardLayoutError)
        -> InterpretedKeyboardKey
    {
        threadAffinity.preconditionIsOwnerThread()

        guard key.evdevKeycode <= UInt32.max - Self.evdevToXKBOffset else {
            throw .invalidKeycode(key.evdevKeycode)
        }

        let xkbKeycode = key.evdevKeycode + Self.evdevToXKBOffset
        let interpretedState = InterpretedKeyboardKeyState(rawValue: key.state.rawValue)
        let keysym = xkb_state_key_get_one_sym(state.pointer, xkbKeycode)
        let isPressLike = interpretedState == .pressed || interpretedState == .repeated

        return InterpretedKeyboardKey(
            serial: key.serial,
            time: key.time,
            evdevKeycode: key.evdevKeycode,
            xkbKeycode: xkbKeycode,
            state: interpretedState,
            keysym: KeyboardKeysym(rawValue: keysym),
            keysymName: keysymName(for: keysym),
            utf8: isPressLike ? utf8Text(for: xkbKeycode) : nil,
            repeats: xkb_keymap_key_repeats(keymap.pointer, xkbKeycode) != 0
        )
    }

    deinit {
        threadAffinity.preconditionIsOwnerThread()
    }

    private func keysymName(for keysym: UInt32) -> String? {
        var buffer = [CChar](repeating: 0, count: 64)
        let required = xkb_keysym_get_name(keysym, &buffer, buffer.count)
        guard required > 0 else { return nil }

        if Int(required) < buffer.count {
            return stringFromNullTerminatedBuffer(buffer)
        }

        buffer = [CChar](repeating: 0, count: Int(required) + 1)
        let written = xkb_keysym_get_name(keysym, &buffer, buffer.count)
        guard written > 0 else { return nil }

        return stringFromNullTerminatedBuffer(buffer)
    }

    private func utf8Text(for xkbKeycode: UInt32) -> String? {
        stringFromXKB { buffer, count in
            xkb_state_key_get_utf8(state.pointer, xkbKeycode, buffer, count)
        }
    }

    private func stringFromXKB(
        _ body: (UnsafeMutablePointer<CChar>?, Int) -> Int32
    ) -> String? {
        let required = body(nil, 0)
        guard required > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: Int(required) + 1)
        let written = body(&buffer, buffer.count)
        guard written > 0 else { return nil }

        let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
        return String(
            bytes: buffer[..<endIndex].map { UInt8(bitPattern: $0) },
            encoding: .utf8
        )
    }

    private func stringFromNullTerminatedBuffer(_ buffer: [CChar]) -> String? {
        let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
        return String(
            bytes: buffer[..<endIndex].map { UInt8(bitPattern: $0) },
            encoding: .utf8
        )
    }
}
