package struct SeatCapabilities:
    OptionSet,
    Sendable,
    Equatable,
    KnownUInt32OptionSet,
    CustomStringConvertible
{
    package let rawValue: UInt32

    package init(rawValue capabilityRawValue: UInt32) {
        rawValue = capabilityRawValue
    }

    package static let pointer = Self(rawValue: 1)
    package static let keyboard = Self(rawValue: 2)
    package static let touch = Self(rawValue: 4)
    package static let known: Self = [.pointer, .keyboard, .touch]

    package var unknownBits: UInt32 {
        unknownRawValue
    }

    package var hasPointer: Bool {
        contains(.pointer)
    }

    package var hasKeyboard: Bool {
        contains(.keyboard)
    }

    package var hasTouch: Bool {
        contains(.touch)
    }

    package var description: String {
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
        if hasUnknownBits {
            names.append("unknown(0x\(String(unknownBits, radix: 16)))")
        }

        return names.isEmpty ? "none" : names.joined(separator: "+")
    }
}
