import Testing

@testable import WaylandClient

@Suite
struct WindowOwnedResourceLedgerTests {
    @Test
    func closeBeforeStartRetiresLateResourceImmediately() {
        let log = RetirementLog()
        let ledger = makeLedger(log)
        ledger.close()

        #expect(!ledger.insert(Resource(id: 1), for: 1))
        #expect(log.ids == [1])
    }

    @Test
    func closeDuringRetirementIsSafe() {
        let log = RetirementLog()
        let holder = LedgerHolder()
        let ledger = WindowOwnedResourceLedger<Int, Resource> { resource in
            log.append(resource.id)
            holder.ledger?.close()
        }
        holder.ledger = ledger
        ledger.insert(Resource(id: 1), for: 1)
        ledger.insert(Resource(id: 2), for: 2)

        ledger.close()

        #expect(log.ids == [1, 2])
    }

    @Test
    func doubleCloseRetiresEachResourceOnce() {
        let log = RetirementLog()
        let ledger = makeLedger(log)
        ledger.insert(Resource(id: 1), for: 1)

        ledger.close()
        ledger.close()

        #expect(log.ids == [1])
    }

    @Test
    func peerRemovalDoesNotRetireRemainingResource() {
        let log = RetirementLog()
        let ledger = makeLedger(log)
        ledger.insert(Resource(id: 1), for: 1)
        ledger.insert(Resource(id: 2), for: 2)

        ledger.retire(1)

        #expect(log.ids == [1])
        #expect(ledger.count == 1)
    }

    @Test
    func mismatchedResourceDoesNotConsumeMatchingIdentity() throws {
        let log = RetirementLog()
        let ledger = makeLedger(log)
        ledger.insert(Resource(id: 1), for: 7)

        #expect(ledger.take(7) { $0.id == 2 } == nil)
        #expect(ledger.count == 1)
        #expect(try #require(ledger.take(7) { $0.id == 1 }).id == 1)
        #expect(ledger.isEmpty)
        #expect(log.ids.isEmpty)
    }

    @Test
    func connectionFailureCleanupRetiresAllResourcesOnce() {
        let log = RetirementLog()
        let ledger = makeLedger(log)
        ledger.insert(Resource(id: 2), for: 2)
        ledger.insert(Resource(id: 1), for: 1)

        ledger.close()

        #expect(log.ids == [1, 2])
        #expect(ledger.isEmpty)
    }

    private func makeLedger(
        _ log: RetirementLog
    ) -> WindowOwnedResourceLedger<Int, Resource> {
        WindowOwnedResourceLedger { log.append($0.id) }
    }
}

private struct Resource {
    let id: Int
}

private final class RetirementLog {
    private(set) var ids: [Int] = []

    func append(_ id: Int) {
        ids.append(id)
    }
}

private final class LedgerHolder {
    var ledger: WindowOwnedResourceLedger<Int, Resource>?
}
