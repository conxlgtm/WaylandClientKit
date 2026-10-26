import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct ToolRuntimeTests {
    @Test
    func headlessWestonReadinessRejectsPlainSocketPathFiles() throws {
        let root = try temporaryRepository()
        defer { ignoreProcessFixtureCleanup { try FileManager.default.removeItem(at: root) } }
        let socketPath = root.appendingPathComponent("wayland-0")
        try "".write(to: socketPath, atomically: true, encoding: .utf8)

        #expect(!HeadlessWestonRunner.isUnixSocket(socketPath))
    }

    @Test
    func headlessWestonTimeoutDefaultsWhenOverrideIsMissingOrEmpty() throws {
        let key = HeadlessWestonRunner.requestProcessTimeoutEnvironmentKey
        let defaultTimeout = HeadlessWestonRunner.defaultRequestProcessTimeoutSeconds

        #expect(
            try HeadlessWestonRunner.requestProcessTimeoutSeconds(environment: [:])
                == defaultTimeout)
        #expect(
            try HeadlessWestonRunner.requestProcessTimeoutSeconds(environment: [key: ""])
                == defaultTimeout)
    }

    @Test
    func headlessWestonTimeoutUsesRequestProcessOverride() throws {
        let key = HeadlessWestonRunner.requestProcessTimeoutEnvironmentKey

        let timeout = try HeadlessWestonRunner.requestProcessTimeoutSeconds(
            environment: [key: "1200.5"])

        #expect(timeout == 1_200.5)
    }

    @Test(arguments: ["nope", "0", "-1", "nan", "inf"])
    func headlessWestonTimeoutRejectsInvalidOverrides(_ value: String) throws {
        let key = HeadlessWestonRunner.requestProcessTimeoutEnvironmentKey

        do {
            _ = try HeadlessWestonRunner.requestProcessTimeoutSeconds(environment: [key: value])
            Issue.record("expected invalid timeout override to fail")
        } catch let error as ToolError {
            #expect(error.message.contains(key))
            #expect(error.exitCode == ToolExitCode.environment)
        }
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-tool-runtime-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
