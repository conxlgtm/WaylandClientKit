import Testing

@testable import WaylandClient

@Suite
struct ArrayRemovalTests {
    @Test
    func removeAllReturningRemovesMatchingElementsInOriginalOrder() {
        var values = [1, 2, 3, 4, 5, 6]

        let removedValues = values.removeAllReturning { $0.isMultiple(of: 2) }

        #expect(removedValues == [2, 4, 6])
        #expect(values == [1, 3, 5])
    }

    @Test
    func removeAllReturningLeavesArrayWhenNoElementsMatch() {
        var values = [1, 3, 5]

        let removedValues = values.removeAllReturning { $0.isMultiple(of: 2) }

        #expect(removedValues.isEmpty)
        #expect(values == [1, 3, 5])
    }
}
