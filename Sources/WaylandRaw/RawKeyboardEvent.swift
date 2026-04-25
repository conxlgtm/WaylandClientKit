package enum RawKeyboardEvent: Equatable, Sendable {
    case keymap(RawKeyboardKeymapInfo)
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

package struct RawKeyboardKeymapPayload: Sendable {
    package let id: RawKeyboardKeymapID
    package let format: RawKeyboardKeymapFormat
    package let size: UInt32
    package let bytes: [UInt8]

    package init(
        id keymapID: RawKeyboardKeymapID,
        format keymapFormat: RawKeyboardKeymapFormat,
        size keymapSize: UInt32,
        bytes keymapBytes: [UInt8]
    ) {
        id = keymapID
        format = keymapFormat
        size = keymapSize
        bytes = keymapBytes
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

package struct RawKeyboardRepeatInfo: Equatable, Sendable {
    package let rate: Int32
    package let delay: Int32

    package init(rate repeatRate: Int32, delay repeatDelay: Int32) {
        rate = repeatRate
        delay = repeatDelay
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
