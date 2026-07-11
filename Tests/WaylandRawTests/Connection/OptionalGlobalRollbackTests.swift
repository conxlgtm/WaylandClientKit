import Testing
@testable import WaylandRaw

struct OptionalGlobalRollbackTests {
    @Test(arguments: 0..<20)
    func destroysEveryAcquiredGlobalOnceInReverseOrder(failureIndex: Int) {
        var destroyed: [Int] = []
        func acquire() {
            let rollback = OptionalGlobalRollback()
            for index in 0..<20 {
                if index == failureIndex {
                    return
                }
                rollback.append { destroyed.append(index) }
            }
        }
        acquire()

        #expect(destroyed == Array((0..<failureIndex).reversed()))
    }

    @Test
    func disarmTransfersCleanupOwnership() {
        var destroyCount = 0
        do {
            let rollback = OptionalGlobalRollback()
            rollback.append { destroyCount += 1 }
            rollback.disarm()
        }

        #expect(destroyCount == 0)
    }
}
