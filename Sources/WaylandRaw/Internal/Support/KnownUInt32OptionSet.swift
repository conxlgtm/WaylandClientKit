package protocol KnownUInt32OptionSet: OptionSet where RawValue == UInt32 {
    static var known: Self { get }
}

extension KnownUInt32OptionSet {
    package var unknownRawValue: UInt32 {
        rawValue & ~Self.known.rawValue
    }

    package var hasUnknownBits: Bool {
        unknownRawValue != 0
    }

    package var containsOnlyKnownBits: Bool {
        !hasUnknownBits
    }
}
