package enum RawKeyboardEvent: Equatable, Sendable {
    case keymap(RawKeyboardKeymapPayload)
    case enter(RawKeyboardEnter)
    case leave(RawKeyboardLeave)
    case key(RawKeyboardKey)
    case modifiers(RawKeyboardModifiers)
    case repeatInfo(RawKeyboardRepeatInfo)
}

package struct RawKeyboardKeymapID: Hashable, Sendable {
    package let seatID: RawSeatID
    package let keyboardGeneration: UInt64
    package let keymapGeneration: UInt64

    package init(
        seatID keymapSeatID: RawSeatID,
        keyboardGeneration keymapKeyboardGeneration: UInt64,
        keymapGeneration rawKeymapGeneration: UInt64
    ) {
        seatID = keymapSeatID
        keyboardGeneration = keymapKeyboardGeneration
        keymapGeneration = rawKeymapGeneration
    }
}

package struct RawKeyboardKeymapInfo: Equatable, Sendable {
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

package struct XKBV1KeymapBytes: Equatable, Sendable {
    private let storage: [UInt8]

    package init(_ keymapBytes: [UInt8]) throws(RawKeyboardKeymapReadError) {
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

    package var count: Int {
        storage.count
    }

    package var countUInt32: UInt32 {
        UInt32(storage.count)
    }

    package var isEmpty: Bool {
        storage.isEmpty
    }

    package var rawValue: [UInt8] {
        storage
    }
}

package enum RawKeyboardKeymapPayload: Equatable, Sendable {
    case noKeymap(id: RawKeyboardKeymapID)
    case xkbV1(id: RawKeyboardKeymapID, bytes: XKBV1KeymapBytes)

    package var id: RawKeyboardKeymapID {
        switch self {
        case .noKeymap(let id), .xkbV1(let id, _):
            id
        }
    }

    package var format: RawKeyboardKeymapFormat {
        switch self {
        case .noKeymap:
            .noKeymap
        case .xkbV1:
            .xkbV1
        }
    }

    package var size: UInt32 {
        switch self {
        case .noKeymap:
            0
        case .xkbV1(_, let bytes):
            bytes.countUInt32
        }
    }

    package var xkbV1Bytes: XKBV1KeymapBytes? {
        switch self {
        case .noKeymap:
            nil
        case .xkbV1(_, let bytes):
            bytes
        }
    }

    package static func xkbV1(
        id keymapID: RawKeyboardKeymapID,
        bytes keymapBytes: [UInt8]
    ) throws(RawKeyboardKeymapReadError) -> Self {
        .xkbV1(id: keymapID, bytes: try XKBV1KeymapBytes(keymapBytes))
    }
}

package struct RawKeyboardEnter: Equatable, Sendable {
    package let serial: UInt32
    package let surfaceID: RawObjectID?
    package let pressedKeys: [UInt32]

    package init(
        serial eventSerial: UInt32,
        surfaceID eventSurfaceID: RawObjectID?,
        pressedKeys eventPressedKeys: [UInt32]
    ) {
        serial = eventSerial
        surfaceID = eventSurfaceID
        pressedKeys = eventPressedKeys
    }
}

package struct RawKeyboardLeave: Equatable, Sendable {
    package let serial: UInt32
    package let surfaceID: RawObjectID?

    package init(serial eventSerial: UInt32, surfaceID eventSurfaceID: RawObjectID?) {
        serial = eventSerial
        surfaceID = eventSurfaceID
    }
}

package struct RawKeyboardKey: Equatable, Sendable {
    package let serial: UInt32
    package let time: UInt32
    package let evdevKeycode: UInt32
    package let state: RawKeyboardKeyState

    package init(
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

package struct RawKeyboardModifiers: Equatable, Sendable {
    package let serial: UInt32
    package let depressed: UInt32
    package let latched: UInt32
    package let locked: UInt32
    package let group: UInt32

    package init(
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

package enum RawKeyboardRepeatInfo: Equatable, Sendable {
    case disabled
    case enabled(rate: RawKeyboardRepeatRate, delay: RawKeyboardRepeatDelay)

    package init(rate repeatRate: Int32, delay repeatDelay: Int32)
        throws(RawKeyboardRepeatInfoError)
    {
        guard repeatDelay >= 0 else {
            throw .negativeDelay(rate: repeatRate, delay: repeatDelay)
        }
        guard repeatRate >= 0 else {
            throw .negativeRate(rate: repeatRate, delay: repeatDelay)
        }
        guard repeatRate > 0 else {
            self = .disabled
            return
        }

        self = .enabled(
            rate: RawKeyboardRepeatRate(unchecked: repeatRate),
            delay: RawKeyboardRepeatDelay(unchecked: repeatDelay)
        )
    }
}

package struct RawKeyboardRepeatRate: Equatable, Comparable, Sendable {
    package let rawValue: Int32

    package init(unchecked value: Int32) {
        precondition(value > 0, "keyboard repeat rate must be positive")
        rawValue = value
    }

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

package struct RawKeyboardRepeatDelay: Equatable, Comparable, Sendable {
    package let rawValue: Int32

    package init(unchecked value: Int32) {
        precondition(value >= 0, "keyboard repeat delay must be non-negative")
        rawValue = value
    }

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

package enum RawKeyboardRepeatInfoError: Error, Equatable, Sendable, CustomStringConvertible {
    case negativeRate(rate: Int32, delay: Int32)
    case negativeDelay(rate: Int32, delay: Int32)

    package var description: String {
        switch self {
        case .negativeRate(let rate, let delay):
            "invalid keyboard repeat info: negative rate \(rate), delay \(delay)"
        case .negativeDelay(let rate, let delay):
            "invalid keyboard repeat info: rate \(rate), negative delay \(delay)"
        }
    }
}

package struct RawKeyboardKeyState: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue stateRawValue: UInt32) {
        rawValue = stateRawValue
    }

    package static let released = Self(rawValue: 0)
    package static let pressed = Self(rawValue: 1)
    package static let repeated = Self(rawValue: 2)
}

package struct RawKeyboardKeymapFormat: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue formatRawValue: UInt32) {
        rawValue = formatRawValue
    }

    package static let noKeymap = Self(rawValue: 0)
    package static let xkbV1 = Self(rawValue: 1)
}

package enum RawKeyboardKeymapReadError: Error, Equatable, Sendable, CustomStringConvertible {
    case unsupportedFormat(format: RawKeyboardKeymapFormat, advertisedSize: UInt32)
    case invalidFileDescriptor(Int32)
    case invalidSizeLimit(maxSize: UInt32, hardMaximumSize: UInt32)
    case emptyXKBV1Payload(size: UInt32)
    case tooLarge(size: UInt32, maxSize: UInt32)
    case tooLargeForProtocolSize(Int)
    case fdTooSmall(size: UInt32, actualSize: Int64)
    case missingNULTerminator(size: UInt32)
    case system(RawSystemError)

    package var description: String {
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
        case .system(let error):
            "system error during keymap read: \(error.description)"
        }
    }
}
