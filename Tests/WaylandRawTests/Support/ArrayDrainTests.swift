import Testing

@testable import WaylandRaw

@Suite
struct ArrayDrainTests {
    @Test
    func drainReturnsElementsAndClearsArray() {
        var values = [1, 2, 3]

        let drainedValues = values.drain()

        #expect(drainedValues == [1, 2, 3])
        #expect(values.isEmpty)
    }

    @Test
    func drainCanDropCapacity() {
        var values = [1, 2, 3]

        _ = values.drain(keepingCapacity: false)

        #expect(values.isEmpty)
    }
}
