import Testing
import WaylandClientKitToolSupport

@Suite(.serialized)
struct ProcessRunnerTests {
    @Test
    func failureIncludesStandardOutputAndStandardError() throws {
        try withToolProcessFixtureLock {
            let shell = try ProcessRunner().executableURL(for: "sh").path

            do {
                _ = try ProcessRunner().run(
                    shell,
                    ["-c", "echo visible-output; echo visible-error >&2; exit 7"]
                )
                Issue.record("expected the command to fail")
            } catch let error as ToolError {
                #expect(error.message.contains("standard output:\nvisible-output"))
                #expect(error.message.contains("standard error:\nvisible-error"))
            }
        }
    }
}
