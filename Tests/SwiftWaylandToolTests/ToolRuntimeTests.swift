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

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftwayland-tool-runtime-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
