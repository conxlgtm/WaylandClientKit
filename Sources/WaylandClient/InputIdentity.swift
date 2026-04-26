public struct SeatID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue seatRawValue: UInt32) {
        rawValue = seatRawValue
    }

    public var description: String {
        "seat-\(rawValue)"
    }
}

public struct WindowID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt64

    public init(rawValue windowRawValue: UInt64) {
        rawValue = windowRawValue
    }

    public var description: String {
        "window-\(rawValue)"
    }
}
