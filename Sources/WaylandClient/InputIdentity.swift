public struct SeatID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue seatRawValue: UInt32) {
        rawValue = seatRawValue
    }

    public var description: String {
        "seat-\(rawValue)"
    }
}

public struct InputSerial:
    ExpressibleByIntegerLiteral,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    public let rawValue: UInt32

    public init(rawValue serialRawValue: UInt32) {
        rawValue = serialRawValue
    }

    public init(integerLiteral value: UInt32) {
        rawValue = value
    }

    public var description: String {
        "serial-\(rawValue)"
    }
}

public struct WindowID: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(rawValue windowRawValue: UInt64) {
        rawValue = windowRawValue
    }

    public var description: String {
        "window-\(rawValue)"
    }
}

public struct PopupSurfaceIdentity: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(_ popupID: PopupID) {
        rawValue = popupID.rawValue
    }

    public var description: String {
        "popup-\(rawValue)"
    }
}

package struct PopupID: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(rawValue popupRawValue: UInt64) {
        rawValue = popupRawValue
    }

    package var description: String {
        "popup-\(rawValue)"
    }
}
