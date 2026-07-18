import Testing

@testable import WaylandClient

@Suite
struct PendingActivationTokenRequestTests {
    @Test
    func everyWaiterReceivesTheFirstCompletedToken() async throws {
        let pending = PendingActivationTokenRequest(id: ActivationRequestID(rawValue: 1))
        let expected = ActivationToken(unchecked: "shared-token")

        try await withThrowingTaskGroup(of: ActivationToken.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    try await pending.value()
                }
            }

            #expect(pending.complete(.success(expected)))
            #expect(!pending.complete(.failure(.cancelled)))
            for try await token in group {
                #expect(token == expected)
            }
        }
    }

    @Test
    func concurrentTokenAndCancellationCompletionChooseOneResult() async {
        for iteration in 0..<100 {
            let pending = PendingActivationTokenRequest(
                id: ActivationRequestID(rawValue: UInt64(iteration + 1))
            )
            let token = ActivationToken(unchecked: "token-\(iteration)")
            let winningCount = await withTaskGroup(of: Bool.self) { group in
                group.addTask {
                    pending.complete(.success(token))
                }
                group.addTask {
                    pending.complete(.failure(.cancelled))
                }

                var count = 0
                for await didComplete in group where didComplete {
                    count += 1
                }
                return count
            }

            #expect(winningCount == 1)
            let completed = pending.completedResult()
            #expect(completed == .success(token) || completed == .failure(.cancelled))
        }
    }
}
