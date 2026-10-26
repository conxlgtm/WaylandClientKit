import Foundation
import Testing
import WaylandClientKitToolSupport

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

@Suite
struct ProcessRunnerTests {
    @Test
    func failureIncludesStandardOutputAndStandardError() async throws {
        let fixture = try ProcessBehaviorFixture()
        defer { fixture.remove() }
        do {
            _ = try await ProcessRunner().run(fixture.executable.path, ["exit", "7"])
            Issue.record("expected the command to fail")
        } catch let error as ToolError {
            #expect(error.message.contains("standard output:\nvisible-output"))
            #expect(error.message.contains("standard error:\nvisible-error"))
            #expect(error.message.contains("exit code 7"))
            #expect(error.message.contains(fixture.executable.path))
            #expect(error.exitCode == ToolExitCode.process)
        }
    }

    @Test(arguments: [nil, "", ":", "::", "/not-a-path-directory"] as [String?])
    func missingAndEmptyPATHDoNotFallback(_ path: String?) throws {
        var environment: [String: String] = [:]
        environment["PATH"] = path
        #expect(throws: ToolError.self) {
            try ProcessRunner(environment: environment).executableURL(for: "sh")
        }
    }

    @Test
    func relativePATHUsesParentDirectoryAndChildOverrideDoesNotSelectExecutable() async throws {
        let fixture = try ProcessBehaviorFixture()
        defer { fixture.remove() }
        let relative = "wck-path-test.\(UUID().uuidString)"
        let parentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let binaries = parentDirectory.appendingPathComponent(relative)
        defer { ignoreProcessFixtureCleanup { try FileManager.default.removeItem(at: binaries) } }
        _ = try fixture.install("selected", in: binaries)
        let childDirectory = fixture.root.appendingPathComponent("cwd")
        try FileManager.default.createDirectory(
            at: childDirectory, withIntermediateDirectories: true)
        let runner = ProcessRunner(environment: [
            "PATH": ":\(relative)::", "PYTHONCOERCECLOCALE": "0",
        ])
        #expect(
            try runner.executableURL(for: "selected").path
                == binaries.appendingPathComponent("selected").path)
        let result = try await runner.run(
            "selected", ["report"], workingDirectory: childDirectory,
            environment: ["PATH": "/not-the-base-path", "MARKER": "override"])
        let info = try report(result.stdout)
        #expect(info["cwd"] as? String == childDirectory.path)
        let childEnvironment = try #require(info["environment"] as? [String: String])
        #expect(
            childEnvironment == [
                "PATH": "/not-the-base-path", "MARKER": "override", "PYTHONCOERCECLOCALE": "0",
            ])
        #expect(FileManager.default.currentDirectoryPath == parentDirectory.path)
        let explicit = "\(relative)/selected"
        let relativeExecutable = try await runner.run(
            explicit, ["exit", "0"], workingDirectory: childDirectory)
        #expect(relativeExecutable.executable == explicit)
        #expect(relativeExecutable.exitCode == 0)
    }

    @Test
    func explicitExecutableNeedsNoPATHAndInheritsStandardInput() async throws {
        let fixture = try ProcessBehaviorFixture()
        defer { fixture.remove() }
        var input = stat()
        try #require(fstat(STDIN_FILENO, &input) == 0)
        let result = try await ProcessRunner(environment: ["PYTHONCOERCECLOCALE": "0"])
            .run(fixture.executable.path, ["report"], workingDirectory: fixture.root)
        let info = try report(result.stdout)
        #expect((info["stdinDevice"] as? NSNumber)?.uint64Value == UInt64(input.st_dev))
        #expect((info["stdinInode"] as? NSNumber)?.uint64Value == UInt64(input.st_ino))
        #expect(info["cwd"] as? String == fixture.root.path)
        #expect(info["environment"] as? [String: String] == ["PYTHONCOERCECLOCALE": "0"])
    }

    @Test
    func capturesLargeSeparateStreamsWithoutDeadlock() async throws {
        let fixture = try ProcessBehaviorFixture()
        defer { fixture.remove() }
        let count = 2 * 1_024 * 1_024
        let result = try await ProcessRunner().run(
            fixture.executable.path, ["streams", "\(count)"])
        #expect(result.stdout == String(repeating: "o", count: count))
        #expect(result.stderr == String(repeating: "e", count: count))
        #expect(result.exitCode == 0)
    }

    @Test
    func invalidUTF8DiscardsTheWholeInvalidStream() async throws {
        let fixture = try ProcessBehaviorFixture()
        defer { fixture.remove() }
        let result = try await ProcessRunner().run(fixture.executable.path, ["invalid"])
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.isEmpty)
    }

    @Test
    func nonzeroAndSignaledStatusRemainResultsWhenRequested() async throws {
        let fixture = try ProcessBehaviorFixture()
        defer { fixture.remove() }
        let runner = ProcessRunner()
        let nonzero = try await runner.run(
            fixture.executable.path, ["exit", "9"], requireSuccess: false)
        #expect(nonzero.exitCode == 9)
        #expect(nonzero.stdout == "visible-output\n")
        #expect(nonzero.stderr == "visible-error\n")
        #expect(nonzero.arguments == ["exit", "9"])
        let signaled = try await runner.run(
            fixture.executable.path, ["signal"], requireSuccess: false)
        #if os(Linux)
            #expect(signaled.exitCode == 128 + SIGTERM)
        #else
            #expect(signaled.exitCode == SIGTERM)
        #endif
    }

    @Test
    func launchWorkingDirectoryAndEnvironmentFailuresAreToolErrors() async throws {
        let fixture = try ProcessBehaviorFixture()
        defer { fixture.remove() }
        let invalid = fixture.root.appendingPathComponent("invalid-executable")
        try "#!/missing/interpreter\n".write(to: invalid, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: invalid.path)
        do {
            _ = try await ProcessRunner().run(invalid.path, [])
            Issue.record("expected launch failure")
        } catch let error as ToolError {
            #expect(error.exitCode == ToolExitCode.process)
            #expect(error.message.contains(invalid.path))
        }
        do {
            _ = try await ProcessRunner().run(
                fixture.executable.path, ["report"],
                workingDirectory: fixture.root.appendingPathComponent("missing"))
            Issue.record("expected cwd failure")
        } catch let error as ToolError {
            #expect(
                error.exitCode == ToolExitCode.process || error.exitCode == ToolExitCode.environment
            )
            #expect(error.message.contains("process") || error.message.contains("directory"))
        }
        for environment in [["BAD=KEY": "value"], ["KEY": "bad\0value"], ["1BAD": "value"]] {
            do {
                _ = try await ProcessRunner(environment: environment).run(
                    fixture.executable.path, ["report"])
                Issue.record("expected malformed environment failure")
            } catch let error as ToolError {
                #expect(error.exitCode == ToolExitCode.process)
                #expect(error.message.contains("Environment"))
            }
        }
    }

    @Test
    func cancellationReapsTheDirectChildAndReleasesDescriptors() async throws {
        let fixture = try ProcessBehaviorFixture()
        defer { fixture.remove() }
        let ready = fixture.root.appendingPathComponent("ready")
        // swiftlint:disable:next no_unstructured_task
        let task = Task { @concurrent in
            try await ProcessRunner().run(
                fixture.executable.path, ["wait", ready.path], requireSuccess: false)
        }
        defer {
            task.cancel()
            _ = await task.result
        }
        do {
            try await fixture.waitForFile(ready)
        } catch {
            task.cancel()
            _ = await task.result
            throw error
        }
        let pid = try #require(Int32(String(contentsOf: ready, encoding: .utf8)))
        #if os(Linux)
            let outputPath = try FileManager.default.destinationOfSymbolicLink(
                atPath: "/proc/\(pid)/fd/1")
        #endif
        task.cancel()
        let result = try await task.value
        #if os(Linux)
            #expect(result.exitCode == 128 + SIGKILL)
        #else
            #expect(result.exitCode == SIGKILL)
        #endif
        fixture.assertReaped(pid)
        #if os(Linux)
            #expect(
                !FileManager.default.fileExists(
                    atPath: URL(fileURLWithPath: outputPath).deletingLastPathComponent().path))
            let descriptors = try FileManager.default.contentsOfDirectory(atPath: "/proc/self/fd")
            let targets: [String] = descriptors.compactMap { descriptor in
                do {
                    return try FileManager.default.destinationOfSymbolicLink(
                        atPath: "/proc/self/fd/\(descriptor)")
                } catch {
                    return nil
                }
            }
            #expect(!targets.contains(outputPath))
        #endif
    }

    private func report(_ text: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }
}
