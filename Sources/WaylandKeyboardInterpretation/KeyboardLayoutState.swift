import CXKBCommonSystem
import Foundation
import WaylandRaw

public enum KeyboardInterpreterError: Error, Equatable, Sendable, CustomStringConvertible {
    case contextCreationFailed

    public var description: String {
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

public struct InterpretedKeyboardEvent: Equatable, Sendable {
    public let sequence: UInt64
    public let seatID: RawSeatID
    public let deviceID: RawInputDeviceID?
    public let kind: InterpretedKeyboardEventKind

    public init(
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

public enum InterpretedKeyboardEventKind: Equatable, Sendable {
    case keymap(InterpretedKeyboardKeymap)
    case key(InterpretedKeyboardKey)
    case modifiers(InterpretedKeyboardModifiers)
    case repeatInfo(InterpretedKeyboardRepeatInfo)
    case unavailable(KeyboardInterpretationUnavailable)
}

public struct InterpretedKeyboardKeymap: Equatable, Sendable {
    public let id: RawKeyboardKeymapID
    public let format: RawKeyboardKeymapFormat
    public let size: UInt32

    public init(
        id keymapID: RawKeyboardKeymapID,
        format keymapFormat: RawKeyboardKeymapFormat,
        size keymapSize: UInt32
    ) {
        id = keymapID
        format = keymapFormat
        size = keymapSize
    }
}

public struct InterpretedKeyboardKey: Equatable, Sendable {
    public let serial: UInt32
    public let time: UInt32
    public let evdevKeycode: UInt32
    public let xkbKeycode: UInt32
    public let state: InterpretedKeyboardKeyState
    public let keysym: KeyboardKeysym
    public let keysymName: String?
    public let utf8: String?
    public let repeats: Bool

    public init(
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

public struct InterpretedKeyboardKeyState: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue stateRawValue: UInt32) {
        rawValue = stateRawValue
    }

    public static let released = Self(rawValue: 0)
    public static let pressed = Self(rawValue: 1)
    public static let repeated = Self(rawValue: 2)
}

public struct KeyboardKeysym: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue keysymRawValue: UInt32) {
        rawValue = keysymRawValue
    }
}

public struct InterpretedKeyboardModifiers: Equatable, Sendable {
    public let serial: UInt32
    public let depressed: UInt32
    public let latched: UInt32
    public let locked: UInt32
    public let group: UInt32
    public let changedComponents: XKBStateComponents

    public init(
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

public struct XKBStateComponents: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue componentsRawValue: UInt32) {
        rawValue = componentsRawValue
    }

    public static let modsDepressed = Self(rawValue: 1 << 0)
    public static let modsLatched = Self(rawValue: 1 << 1)
    public static let modsLocked = Self(rawValue: 1 << 2)
    public static let modsEffective = Self(rawValue: 1 << 3)
    public static let layoutDepressed = Self(rawValue: 1 << 4)
    public static let layoutLatched = Self(rawValue: 1 << 5)
    public static let layoutLocked = Self(rawValue: 1 << 6)
    public static let layoutEffective = Self(rawValue: 1 << 7)
    public static let leds = Self(rawValue: 1 << 8)
}

public struct InterpretedKeyboardRepeatInfo: Equatable, Sendable {
    public let rate: Int32
    public let delay: Int32

    public init(rate repeatRate: Int32, delay repeatDelay: Int32) {
        rate = repeatRate
        delay = repeatDelay
    }
}

public struct KeyboardInterpretationUnavailable: Equatable, Sendable {
    public let reason: KeyboardInterpretationUnavailableReason

    public init(reason unavailableReason: KeyboardInterpretationUnavailableReason) {
        reason = unavailableReason
    }
}

public enum KeyboardInterpretationUnavailableReason: Equatable, Sendable {
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
