package protocol WaylandEntityID:
    Hashable,
    Sendable,
    CustomStringConvertible
{
    associatedtype RawValue: Hashable & Sendable

    var rawValue: RawValue { get }
}

package protocol UInt64WaylandEntityID: WaylandEntityID where RawValue == UInt64 {
    init(rawValue: UInt64)
}

package protocol UInt32WaylandEntityID: WaylandEntityID where RawValue == UInt32 {
    init(rawValue: UInt32)
}

package protocol PrefixedIdentityDescription {
    static var descriptionPrefix: String { get }
}

package struct IDGenerator<ID>: Sendable, Equatable {
    private var nextRawValue: UInt64

    package init(startingAt value: UInt64 = 1) {
        precondition(value != 0, "generated SwiftWayland IDs reserve zero")
        nextRawValue = value
    }

    package mutating func nextRawValueForCompositeID() -> UInt64 {
        precondition(nextRawValue != UInt64.max, "SwiftWayland ID domain exhausted")
        defer { nextRawValue += 1 }
        return nextRawValue
    }
}

extension IDGenerator where ID: UInt64WaylandEntityID {
    package mutating func next() -> ID {
        ID(rawValue: nextRawValueForCompositeID())
    }
}

