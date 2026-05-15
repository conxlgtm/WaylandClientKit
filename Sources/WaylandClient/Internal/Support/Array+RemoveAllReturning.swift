extension Array {
    package mutating func removeAllReturning(
        where shouldRemove: (Element) throws -> Bool
    ) rethrows -> [Element] {
        var kept: [Element] = []
        var removed: [Element] = []
        kept.reserveCapacity(count)

        for element in self {
            if try shouldRemove(element) {
                removed.append(element)
            } else {
                kept.append(element)
            }
        }

        self = kept
        return removed
    }
}
