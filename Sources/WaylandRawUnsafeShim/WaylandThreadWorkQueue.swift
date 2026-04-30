@safe
struct WaylandThreadWorkQueue<Element> {
    private var storage: [Element?] = []
    private var headIndex = 0

    var isEmpty: Bool {
        headIndex >= storage.count
    }

    mutating func append(_ element: Element) {
        storage.append(element)
    }

    mutating func popFirst() -> Element? {
        guard headIndex < storage.count else { return nil }

        let element = storage[headIndex]
        storage[headIndex] = nil
        headIndex += 1
        compactIfNeeded()
        return element
    }

    func count(where shouldCount: (Element) -> Bool) -> Int {
        var matchingCount = 0

        for index in headIndex..<storage.count {
            guard let element = storage[index], shouldCount(element) else {
                continue
            }

            matchingCount += 1
        }

        return matchingCount
    }

    private mutating func compactIfNeeded() {
        guard headIndex > 1_024,
            headIndex * 2 > storage.count
        else { return }

        storage.removeFirst(headIndex)
        headIndex = 0
    }
}
