import Testing

@testable import WaylandKeyboard

@Suite(.timeLimit(.minutes(1)))
struct KeyboardComposeConcurrencyTests {
    @Test
    func concurrentLocaleComposeTableCreationCompletes() async throws {
        let createdCount = try await interpreterCreationCount(
            configuration: KeyboardInterpreterConfiguration(
                compose: .enabled(locale: .identifier(.posixC))
            )
        )

        #expect(createdCount == 16)
    }

    @Test
    func concurrentBufferComposeTableCreationCompletes() async throws {
        let createdCount = try await interpreterCreationCount(
            configuration: KeyboardInterpreterConfiguration(
                compose: .tableBuffer(composeTableText())
            )
        )

        #expect(createdCount == 16)
    }

    private func interpreterCreationCount(
        configuration: KeyboardInterpreterConfiguration,
        count: Int = 16
    ) async throws -> Int {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            for _ in 0..<count {
                group.addTask {
                    _ = try KeyboardInterpreter(
                        configuration: configuration,
                        composeEnvironment: KeyboardComposeEnvironment()
                    )
                    return true
                }
            }

            var createdCount = 0
            for try await didCreate in group where didCreate {
                createdCount += 1
            }
            return createdCount
        }
    }
}
