import WaylandRaw

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

extension SeatID: RawValueOrdered {}
extension WindowID: RawValueOrdered {}
extension OutputID: RawValueOrdered {}
extension DataOfferID: RawValueOrdered {}
extension DataSourceID: RawValueOrdered {}
extension RawSeatID: RawValueOrdered {}
