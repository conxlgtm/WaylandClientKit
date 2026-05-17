public struct ByteCount: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public static let defaultTransferReadLimit = ByteCount(unchecked: 16 * 1_024 * 1_024)

    public init(_ value: Int) throws {
        guard value >= 0 else {
            throw DataTransferError.negativeByteCount(value)
        }

        rawValue = value
    }

    public static func bytes(_ value: Int) throws -> ByteCount {
        try ByteCount(value)
    }

    public static func kilobytes(_ value: Int) throws -> ByteCount {
        try scaled(value, by: 1_024)
    }

    public static func megabytes(_ value: Int) throws -> ByteCount {
        try scaled(value, by: 1_024 * 1_024)
    }

    package init(unchecked value: Int) {
        precondition(value >= 0, "byte count must be non-negative")
        rawValue = value
    }

    public var description: String {
        "\(rawValue) bytes"
    }

    public static func < (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static func scaled(_ value: Int, by multiplier: Int) throws -> ByteCount {
        guard value >= 0 else {
            throw DataTransferError.negativeByteCount(value)
        }

        let product = value.multipliedReportingOverflow(by: multiplier)
        guard !product.overflow else {
            throw DataTransferError.byteCountOverflow(value: value, multiplier: multiplier)
        }

        return try ByteCount(product.partialValue)
    }
}
