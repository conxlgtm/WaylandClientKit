public struct RawObjectID: Hashable, Sendable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    public let value: UInt32

    public init(_ value: UInt32) {
        self.value = value
    }

    public init(integerLiteral value: UInt32) {
        self.init(value)
    }

    public var description: String {
        "id=\(self.value)"
    }
}
