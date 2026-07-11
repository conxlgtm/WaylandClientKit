import Testing

@testable import WaylandRuntime

struct FIFOQueueTests {
    @Test
    func preservesOrderAcrossCompaction() {
        var queue: FIFOQueue<Int> = []
        for value in 0..<3_000 { queue.append(value) }

        for expected in 0..<2_500 {
            #expect(queue.popFirst() == expected)
        }
        #expect(queue.first == 2_500)
        #expect(queue.count == 500)
        #expect(queue.count { $0.isMultiple(of: 2) } == 250)
    }

    @Test
    func removeAllResetsTheHead() {
        var queue: FIFOQueue<Int> = [1, 2]
        #expect(queue.popFirst() == 1)
        queue.removeAll(keepingCapacity: true)
        queue.append(3)

        #expect(queue.popFirst() == 3)
        #expect(queue.isEmpty)
    }
}
