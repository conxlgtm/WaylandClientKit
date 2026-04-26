public struct SeatCapabilities: OptionSet, Sendable, Equatable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue capabilityRawValue: UInt32) {
        rawValue = capabilityRawValue
    }

    public static let pointer = Self(rawValue: 1)
    public static let keyboard = Self(rawValue: 2)
    public static let touch = Self(rawValue: 4)

    public var hasPointer: Bool {
        contains(.pointer)
    }

    public var hasKeyboard: Bool {
        contains(.keyboard)
    }

    public var hasTouch: Bool {
        contains(.touch)
    }

    public var description: String {
        var names: [String] = []

        if contains(.pointer) {
            names.append("pointer")
        }
        if contains(.keyboard) {
            names.append("keyboard")
        }
        if contains(.touch) {
            names.append("touch")
        }

        return names.isEmpty ? "none" : names.joined(separator: "+")
    }
}
