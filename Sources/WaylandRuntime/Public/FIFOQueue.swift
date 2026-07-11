@safe
package struct FIFOQueue<Element>: ExpressibleByArrayLiteral {
    private var storage: [Element?] = []
    private var headIndex = 0

    package init() {}

    package init(arrayLiteral elements: Element...) {
        storage = elements.map(Optional.some)
    }

    package var isEmpty: Bool { headIndex >= storage.count }
    package var count: Int { storage.count - headIndex }
    package var first: Element? {
        guard headIndex < storage.count else { return nil }
        return storage[headIndex]
    }

    package mutating func append(_ element: Element) { storage.append(element) }

    package mutating func append(contentsOf elements: [Element]) {
        storage.append(contentsOf: elements.map(Optional.some))
    }

    package mutating func popFirst() -> Element? {
        guard headIndex < storage.count else { return nil }
        let element = storage[headIndex]
        storage[headIndex] = nil
        headIndex += 1
        compactIfNeeded()
        return element
    }

    package mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        storage.removeAll(keepingCapacity: keepCapacity)
        headIndex = 0
    }

    package mutating func drain(keepingCapacity keepCapacity: Bool = false) -> [Element] {
        let elements = Array(storage[headIndex...].compactMap { $0 })
        removeAll(keepingCapacity: keepCapacity)
        return elements
    }

    package mutating func removeAllReturning(
        where shouldRemove: (Element) -> Bool
    ) -> [Element] {
        var retained: [Element?] = []
        var removed: [Element] = []
        for element in storage[headIndex...].compactMap({ $0 }) {
            if shouldRemove(element) {
                removed.append(element)
            } else {
                retained.append(element)
            }
        }
        storage = retained
        headIndex = 0
        return removed
    }

    package func count(where shouldCount: (Element) -> Bool) -> Int {
        storage[headIndex...].compactMap { $0 }.count(where: shouldCount)
    }

    private mutating func compactIfNeeded() {
        guard headIndex > 1_024, headIndex * 2 > storage.count else { return }
        storage.removeFirst(headIndex)
        headIndex = 0
    }
}
