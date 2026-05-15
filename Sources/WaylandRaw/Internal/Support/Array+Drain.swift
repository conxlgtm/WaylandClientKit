extension Array {
    package mutating func drain(keepingCapacity: Bool = true) -> [Element] {
        defer { removeAll(keepingCapacity: keepingCapacity) }
        return self
    }
}
