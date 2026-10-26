import Foundation
import Testing
import WaylandClientKitToolSupport

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

struct ProcessBehaviorFixture: Sendable {
    let root: URL
    let python: String
    let executable: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wck-process-test.\(UUID().uuidString)")
        python = try ProcessRunner().executableURL(for: "python3").path
        executable = root.appendingPathComponent("process-fixture")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = try #require(
            Bundle.module.url(
                forResource: "process-behavior", withExtension: "py", subdirectory: "Fixtures"))
        let text = try String(contentsOf: source, encoding: .utf8)
        try ("#!\(python)\n" + text).write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: executable.path)
    }

    func install(_ name: String, in directory: URL? = nil) throws -> URL {
        let directory = directory ?? root
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent(name)
        try FileManager.default.copyItem(at: executable, to: path)
        return path
    }

    func waitForFile(_ url: URL, containing text: String? = nil) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while clock.now < deadline {
            if let contents = processFixtureText(url),
                text.map({ contents.contains($0) }) ?? true
            {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw ToolError("fixture did not produce \(url.path): \(text ?? "")")
    }

    func assertReaped(_ processID: Int32) {
        errno = 0
        #expect(kill(processID, 0) == -1)
        #expect(errno == ESRCH)
    }

    func remove() {
        ignoreProcessFixtureCleanup { try FileManager.default.removeItem(at: root) }
    }
}

func processFixtureText(_ url: URL) -> String? {
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        return nil
    }
}

func ignoreProcessFixtureCleanup(_ operation: () throws -> Void) {
    do {
        try operation()
    } catch {
        // Fixture cleanup is best-effort.
    }
}
