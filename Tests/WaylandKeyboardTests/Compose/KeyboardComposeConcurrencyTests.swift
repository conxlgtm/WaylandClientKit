import Testing

@testable import WaylandKeyboard

@Suite
struct KeyboardComposeConcurrencyTests {
    @Test
    func concurrentLocaleComposeTableCreationCompletes() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    _ = try KeyboardInterpreter(
                        configuration: KeyboardInterpreterConfiguration(
                            compose: .enabled(locale: .identifier(.posixC))
                        ),
                        composeEnvironment: KeyboardComposeEnvironment()
                    )
                }
            }

            try await group.waitForAll()
        }
    }

    @Test
    func concurrentBufferComposeTableCreationCompletes() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    _ = try KeyboardInterpreter(
                        configuration: KeyboardInterpreterConfiguration(
                            compose: .tableBuffer(composeTableText())
                        ),
                        composeEnvironment: KeyboardComposeEnvironment()
                    )
                }
            }

            try await group.waitForAll()
        }
    }
}
