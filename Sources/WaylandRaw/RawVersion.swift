public struct RawVersion: Hashable, Sendable, Comparable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    public let value: UInt32

    public init(_ value: UInt32) {
        self.value = value
    }

    public init(integerLiteral value: UInt32) {
        self.init(value)
    }

    public static func < (lhs: RawVersion, rhs: RawVersion) -> Bool {
        lhs.value < rhs.value
    }

    public var description: String {
        "v\(self.value)"
    }
}
