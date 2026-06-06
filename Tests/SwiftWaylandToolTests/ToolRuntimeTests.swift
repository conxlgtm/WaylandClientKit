import Foundation
import SwiftWaylandToolSupport
import Testing

@Suite
struct ToolRuntimeTests {
    @Test
    func cCompilerFilterResolvesBareExecutableThroughPath() throws {
        let root = try temporaryRepository()
        let bin = root.appendingPathComponent("bin")
        let swl = bin.appendingPathComponent("swl")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try "".write(to: swl, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: swl.path)

        let resolved = try CCompilerFilter.filterExecutableURL(
            commandPath: "swl",
            workingDirectory: root,
            runner: ProcessRunner(environment: ["PATH": bin.path])
        )

        #expect(resolved.path == swl.standardizedFileURL.path)
    }

    @Test
    func headlessWestonReadinessRejectsPlainSocketPathFiles() throws {
        let root = try temporaryRepository()
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

    @Test
    func headlessWestonTimeoutRejectsInvalidOverrides() throws {
        let key = HeadlessWestonRunner.requestProcessTimeoutEnvironmentKey

        do {
            _ = try HeadlessWestonRunner.requestProcessTimeoutSeconds(environment: [key: "nope"])
            Issue.record("expected invalid timeout override to fail")
        } catch let error as ToolError {
            #expect(error.message.contains(key))
            #expect(error.exitCode == ToolExitCode.environment)
        }
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftwayland-tool-runtime-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
