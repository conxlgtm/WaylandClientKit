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

public struct XKBV1KeymapBytes: Equatable, Sendable {
    private let storage: [UInt8]

    public init(_ keymapBytes: [UInt8]) throws(RawKeyboardKeymapReadError) {
        guard UInt64(keymapBytes.count) <= UInt64(UInt32.max) else {
            throw .tooLargeForProtocolSize(keymapBytes.count)
        }

        let count = UInt32(keymapBytes.count)

        guard keymapBytes.count > 1 else {
            throw .emptyXKBV1Payload(size: count)
        }

        guard keymapBytes.last == 0 else {
            throw .missingNULTerminator(size: count)
        }

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

    public var rawValue: [UInt8] {
        storage
    }
}

public enum RawKeyboardKeymapPayload: Equatable, Sendable {
    case noKeymap(id: RawKeyboardKeymapID)
    case xkbV1(id: RawKeyboardKeymapID, bytes: XKBV1KeymapBytes)

    public var id: RawKeyboardKeymapID {
        switch self {
        case .noKeymap(let id), .xkbV1(let id, _):
            id
        }
    }

    public var format: RawKeyboardKeymapFormat {
        switch self {
        case .noKeymap:
            .noKeymap
        case .xkbV1:
            .xkbV1
        }
    }

    public var size: UInt32 {
        switch self {
        case .noKeymap:
            0
        case .xkbV1(_, let bytes):
            bytes.countUInt32
        }
    }

    public var xkbV1Bytes: XKBV1KeymapBytes? {
        switch self {
        case .noKeymap:
            nil
        case .xkbV1(_, let bytes):
            bytes
        }
    }

    public static func xkbV1(
        id keymapID: RawKeyboardKeymapID,
        bytes keymapBytes: [UInt8]
    ) throws(RawKeyboardKeymapReadError) -> Self {
        .xkbV1(id: keymapID, bytes: try XKBV1KeymapBytes(keymapBytes))
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

public enum RawKeyboardKeymapReadOperation: Equatable, Sendable, CustomStringConvertible {
    case fstat
    case mmap

    public var description: String {
        switch self {
        case .fstat:
            "fstat"
        case .mmap:
            "mmap"
        }
    }
}

public enum RawKeyboardKeymapReadError: Error, Equatable, Sendable, CustomStringConvertible {
    case unsupportedFormat(format: RawKeyboardKeymapFormat, advertisedSize: UInt32)
    case invalidFileDescriptor(Int32)
    case invalidSizeLimit(maxSize: UInt32, hardMaximumSize: UInt32)
    case emptyXKBV1Payload(size: UInt32)
    case tooLarge(size: UInt32, maxSize: UInt32)
    case tooLargeForProtocolSize(Int)
    case fdTooSmall(size: UInt32, actualSize: Int64)
    case missingNULTerminator(size: UInt32)
    case system(errno: Int32, operation: RawKeyboardKeymapReadOperation)

    public var description: String {
        switch self {
        case .unsupportedFormat(let format, let advertisedSize):
            "unsupported keymap format \(format.rawValue) with advertised size \(advertisedSize)"
        case .invalidFileDescriptor(let descriptor):
            "invalid keymap file descriptor \(descriptor)"
        case .invalidSizeLimit(let maxSize, let hardMaximumSize):
            "invalid keymap size limit \(maxSize); maximum supported limit is \(hardMaximumSize)"
        case .emptyXKBV1Payload(let size):
            "empty xkb_v1 keymap payload with advertised size \(size)"
        case .tooLarge(let size, let maxSize):
            "keymap size \(size) exceeds configured maximum \(maxSize)"
        case .tooLargeForProtocolSize(let byteCount):
            "keymap byte count \(byteCount) exceeds UInt32"
        case .fdTooSmall(let size, let actualSize):
            "keymap fd contains \(actualSize) bytes, fewer than advertised size \(size)"
        case .missingNULTerminator(let size):
            "xkb_v1 keymap of size \(size) is not NUL-terminated"
        case .system(let errno, let operation):
            "system error during keymap \(operation): errno \(errno)"
        }
    }
}
