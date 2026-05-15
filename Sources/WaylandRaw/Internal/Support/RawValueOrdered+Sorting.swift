package protocol RawValueOrdered {
    associatedtype RawValue: Comparable

    var rawValue: RawValue { get }
}

extension Sequence where Element: RawValueOrdered {
    package func sortedByRawValue() -> [Element] {
        sorted { $0.rawValue < $1.rawValue }
    }
}

extension Sequence {
    package func sortedByRawValue<ID: RawValueOrdered>(
        _ keyPath: KeyPath<Element, ID>
    ) -> [Element] {
        sorted { lhs, rhs in
            lhs[keyPath: keyPath].rawValue < rhs[keyPath: keyPath].rawValue
        }
    }
}

extension Array where Element: RawValueOrdered {
    package mutating func sortByRawValue() {
        sort { $0.rawValue < $1.rawValue }
    }
}

extension Dictionary where Key: Comparable {
    package func valuesSortedByKey() -> [Value] {
        sorted { $0.key < $1.key }.map(\.value)
    }
}

extension RawSeatID: RawValueOrdered {}
extension RawOutputID: RawValueOrdered {}
