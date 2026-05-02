public enum RawKeyboardEvent: Equatable, Sendable {
    case keymap(RawKeyboardKeymapPayload)
    case enter(RawKeyboardEnter)
    case leave(RawKeyboardLeave)
    case key(RawKeyboardKey)
    case modifiers(RawKeyboardModifiers)
    case repeatInfo(RawKeyboardRepeatInfo)
}

public struct RawKeyboardKeymapID: Hashable, Sendable {
    public let seatID: RawSeatID
    public let keyboardGeneration: UInt64
    public let keymapGeneration: UInt64

    public init(
        seatID keymapSeatID: RawSeatID,
        keyboardGeneration keymapKeyboardGeneration: UInt64,
        keymapGeneration rawKeymapGeneration: UInt64
    ) {
        seatID = keymapSeatID
        keyboardGeneration = keymapKeyboardGeneration
        keymapGeneration = rawKeymapGeneration
    }
}

public struct RawKeyboardKeymapInfo: Equatable, Sendable {
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

public struct KeymapBytes: Equatable, Sendable {
    private let storage: [UInt8]

    public init(_ keymapBytes: [UInt8]) {
        precondition(
            UInt64(keymapBytes.count) <= UInt64(UInt32.max),
            "keymap byte count exceeds UInt32"
        )

        storage = keymapBytes
    }

    public var count: Int {
        storage.count
    }

    public var countUInt32: UInt32 {
        UInt32(storage.count)
    }

    public var isEmpty: Bool {
        storage.isEmpty
    }

    public var array: [UInt8] {
        storage
    }
}

public struct RawKeyboardKeymapPayload: Equatable, Sendable {
    public let id: RawKeyboardKeymapID
    public let format: RawKeyboardKeymapFormat
    public let bytes: KeymapBytes

    public var size: UInt32 {
        bytes.countUInt32
    }

    public init(
        id keymapID: RawKeyboardKeymapID,
        format keymapFormat: RawKeyboardKeymapFormat,
        bytes keymapBytes: KeymapBytes
    ) {
        id = keymapID
        format = keymapFormat
        bytes = keymapBytes
    }

    public init(
        id keymapID: RawKeyboardKeymapID,
        format keymapFormat: RawKeyboardKeymapFormat,
        bytes keymapBytes: [UInt8]
    ) {
        id = keymapID
        format = keymapFormat
        bytes = KeymapBytes(keymapBytes)
    }
}

public struct RawKeyboardEnter: Equatable, Sendable {
    public let serial: UInt32
    public let surfaceID: RawObjectID?
    public let pressedKeys: [UInt32]

    public init(
        serial eventSerial: UInt32,
        surfaceID eventSurfaceID: RawObjectID?,
        pressedKeys eventPressedKeys: [UInt32]
    ) {
        serial = eventSerial
        surfaceID = eventSurfaceID
        pressedKeys = eventPressedKeys
    }
}

public struct RawKeyboardLeave: Equatable, Sendable {
    public let serial: UInt32
    public let surfaceID: RawObjectID?

    public init(serial eventSerial: UInt32, surfaceID eventSurfaceID: RawObjectID?) {
        serial = eventSerial
        surfaceID = eventSurfaceID
    }
}

public struct RawKeyboardKey: Equatable, Sendable {
    public let serial: UInt32
    public let time: UInt32
    public let evdevKeycode: UInt32
    public let state: RawKeyboardKeyState

    public init(
        serial eventSerial: UInt32,
        time eventTime: UInt32,
        evdevKeycode eventEvdevKeycode: UInt32,
        state eventState: RawKeyboardKeyState
    ) {
        serial = eventSerial
        time = eventTime
        evdevKeycode = eventEvdevKeycode
        state = eventState
    }
}

public struct RawKeyboardModifiers: Equatable, Sendable {
    public let serial: UInt32
    public let depressed: UInt32
    public let latched: UInt32
    public let locked: UInt32
    public let group: UInt32

    public init(
        serial eventSerial: UInt32,
        depressed eventDepressed: UInt32,
        latched eventLatched: UInt32,
        locked eventLocked: UInt32,
        group eventGroup: UInt32
    ) {
        serial = eventSerial
        depressed = eventDepressed
        latched = eventLatched
        locked = eventLocked
        group = eventGroup
    }
}

public struct RawKeyboardRepeatInfo: Equatable, Sendable {
    public let rate: Int32
    public let delay: Int32

    public init(rate repeatRate: Int32, delay repeatDelay: Int32) {
        rate = repeatRate
        delay = repeatDelay
    }
}

public struct RawKeyboardKeyState: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue stateRawValue: UInt32) {
        rawValue = stateRawValue
    }

    public static let released = Self(rawValue: 0)
    public static let pressed = Self(rawValue: 1)
    public static let repeated = Self(rawValue: 2)
}

public struct RawKeyboardKeymapFormat: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue formatRawValue: UInt32) {
        rawValue = formatRawValue
    }

    public static let noKeymap = Self(rawValue: 0)
    public static let xkbV1 = Self(rawValue: 1)
}
