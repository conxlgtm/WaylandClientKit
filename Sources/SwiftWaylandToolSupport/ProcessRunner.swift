import Foundation

#if os(Linux)
    import Glibc
#endif

// POSIX spawn setup is necessarily dense because argv/envp lifetime and fd actions stay together.
// swiftlint:disable function_body_length type_body_length

public struct ProcessResult: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(
        executable: String,
        arguments: [String],
        exitCode: Int32,
        stdout: String,
        stderr: String
    ) {
        self.executable = executable
        self.arguments = arguments
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    public var commandLine: String {
        ([executable] + arguments).joined(separator: " ")
    }
}

public struct ProcessRunner: Sendable {
    public var environment: [String: String]
    public var diagnostics: Diagnostics

    #if os(Linux)
        private static let currentDirectorySpawnLock = NSLock()
    #endif

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        diagnostics: Diagnostics = Diagnostics()
    ) {
        self.environment = environment
        self.diagnostics = diagnostics
    }

    @discardableResult
    public func run(
        _ executable: String,
        _ arguments: [String],
        workingDirectory: URL? = nil,
        environment overrides: [String: String] = [:],
        requireSuccess: Bool = true
    ) throws -> ProcessResult {
        diagnostics.verbose("running \(([executable] + arguments).joined(separator: " "))")

        #if os(Linux)
            return try runPOSIX(
                executable,
                arguments,
                workingDirectory: workingDirectory,
                environment: overrides,
                requireSuccess: requireSuccess)
        #else
            let process = Process()
            process.executableURL = try executableURL(for: executable)
            process.arguments = arguments
            if let workingDirectory {
                process.currentDirectoryURL = workingDirectory
            }
            process.environment = mergedEnvironment(overrides)

            let outputDirectory = try temporaryOutputDirectory()
            defer { ignoreCleanupError { try FileManager.default.removeItem(at: outputDirectory) } }
            let stdoutURL = outputDirectory.appendingPathComponent("stdout")
            let stderrURL = outputDirectory.appendingPathComponent("stderr")
            _ = FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
            _ = FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
            let stdout = try FileHandle(forWritingTo: stdoutURL)
            let stderr = try FileHandle(forWritingTo: stderrURL)
            defer {
                ignoreCleanupError { try stdout.close() }
                ignoreCleanupError { try stderr.close() }
            }
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            process.waitUntilExit()
            try stdout.close()
            try stderr.close()

            let stdoutData = try Data(contentsOf: stdoutURL)
            let stderrData = try Data(contentsOf: stderrURL)
            let result = ProcessResult(
                executable: executable,
                arguments: arguments,
                exitCode: process.terminationStatus,
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? ""
            )

            if requireSuccess, result.exitCode != 0 {
                throw ToolError(
                    """
                    command failed with exit code \(result.exitCode): \(result.commandLine)
                    \(result.stderr.isEmpty ? result.stdout : result.stderr)
                    """,
                    exitCode: ToolExitCode.process
                )
            }

            return result
        #endif
    }

    public func executableURL(for executable: String) throws -> URL {
        if executable.contains("/") {
            let url = URL(fileURLWithPath: executable)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
            throw ToolError(
                "executable is not runnable: \(executable)", exitCode: ToolExitCode.environment)
        }

        for directory in pathDirectories() {
            let candidate = directory.appendingPathComponent(executable)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        throw ToolError(
            "executable not found on PATH: \(executable)", exitCode: ToolExitCode.environment)
    }

    public func canFind(_ executable: String) -> Bool {
        do {
            _ = try executableURL(for: executable)
            return true
        } catch {
            return false
        }
    }

    private func mergedEnvironment(_ overrides: [String: String]) -> [String: String] {
        var merged = environment
        for (key, value) in overrides {
            merged[key] = value
        }
        return merged
    }

    private func pathDirectories() -> [URL] {
        environment["PATH", default: ""]
            .split(separator: ":", omittingEmptySubsequences: true)
            .map { URL(fileURLWithPath: String($0)) }
    }

    private func temporaryOutputDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftwayland-process.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    #if os(Linux)
        private func runPOSIX(
            _ executable: String,
            _ arguments: [String],
            workingDirectory: URL?,
            environment overrides: [String: String],
            requireSuccess: Bool
        ) throws -> ProcessResult {
            let executablePath = try executableURL(for: executable).path
            let outputDirectory = try temporaryOutputDirectory()
            defer { ignoreCleanupError { try FileManager.default.removeItem(at: outputDirectory) } }

            let stdoutURL = outputDirectory.appendingPathComponent("stdout")
            let stderrURL = outputDirectory.appendingPathComponent("stderr")
            let stdoutFD = try openOutputFile(stdoutURL)
            let stderrFD = try openOutputFile(stderrURL)
            defer {
                close(stdoutFD)
                close(stderrFD)
            }

            var actions = posix_spawn_file_actions_t()
            posix_spawn_file_actions_init(&actions)
            defer { posix_spawn_file_actions_destroy(&actions) }
            posix_spawn_file_actions_adddup2(&actions, stdoutFD, STDOUT_FILENO)
            posix_spawn_file_actions_adddup2(&actions, stderrFD, STDERR_FILENO)

            let spawnStatus: Int32
            var processID = pid_t()
            Self.currentDirectorySpawnLock.lock()
            let originalDirectory = FileManager.default.currentDirectoryPath
            var changedDirectory = false
            do {
                if let workingDirectory {
                    guard FileManager.default.changeCurrentDirectoryPath(workingDirectory.path)
                    else {
                        throw ToolError(
                            "failed to change directory to \(workingDirectory.path)",
                            exitCode: ToolExitCode.environment)
                    }
                    changedDirectory = true
                }

                let merged = mergedEnvironment(overrides)
                let environmentStrings = merged.map { "\($0.key)=\($0.value)" }.sorted()
                spawnStatus = try withCStringArray([executablePath] + arguments) { argv in
                    try withCStringArray(environmentStrings) { environment in
                        executablePath.withCString { path in
                            posix_spawn(&processID, path, &actions, nil, argv, environment)
                        }
                    }
                }

                if changedDirectory {
                    _ = FileManager.default.changeCurrentDirectoryPath(originalDirectory)
                    changedDirectory = false
                }
                Self.currentDirectorySpawnLock.unlock()
            } catch {
                if changedDirectory {
                    _ = FileManager.default.changeCurrentDirectoryPath(originalDirectory)
                }
                Self.currentDirectorySpawnLock.unlock()
                throw error
            }
            guard spawnStatus == 0 else {
                throw ToolError(
                    "failed to launch \(executable): \(String(cString: strerror(spawnStatus)))",
                    exitCode: ToolExitCode.process)
            }

            var status: Int32 = 0
            while waitpid(processID, &status, 0) == -1 {
                if errno == EINTR {
                    continue
                }
                throw ToolError(
                    "failed to wait for \(executable): \(String(cString: strerror(errno)))",
                    exitCode: ToolExitCode.process)
            }

            let result = ProcessResult(
                executable: executable,
                arguments: arguments,
                exitCode: terminationStatus(status),
                stdout: String(data: try Data(contentsOf: stdoutURL), encoding: .utf8) ?? "",
                stderr: String(data: try Data(contentsOf: stderrURL), encoding: .utf8) ?? ""
            )
            if requireSuccess, result.exitCode != 0 {
                throw ToolError(
                    """
                    command failed with exit code \(result.exitCode): \(result.commandLine)
                    \(result.stderr.isEmpty ? result.stdout : result.stderr)
                    """,
                    exitCode: ToolExitCode.process
                )
            }
            return result
        }

        private func openOutputFile(_ url: URL) throws -> Int32 {
            let descriptor = url.path.withCString { path in
                open(path, O_WRONLY | O_CREAT | O_TRUNC, mode_t(0o600))
            }
            guard descriptor >= 0 else {
                throw ToolError(
                    "failed to open process output file \(url.path): "
                        + String(cString: strerror(errno)),
                    exitCode: ToolExitCode.environment)
            }
            return descriptor
        }

        private func terminationStatus(_ status: Int32) -> Int32 {
            let signal = status & 0x7f
            if signal == 0 {
                return (status & 0xff00) >> 8
            }
            if signal != 0x7f {
                return 128 + signal
            }
            return ToolExitCode.process
        }

        private func withCStringArray<T>(
            _ strings: [String],
            _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> T
        ) throws -> T {
            var pointers: [UnsafeMutablePointer<CChar>] = []
            for string in strings {
                guard let pointer = strdup(string) else {
                    throw ToolError(
                        "failed to allocate process argument storage",
                        exitCode: ToolExitCode.process)
                }
                pointers.append(pointer)
            }
            defer {
                for pointer in pointers {
                    free(pointer)
                }
            }
            var array: [UnsafeMutablePointer<CChar>?] = pointers.map { Optional($0) }
            array.append(nil)
            return try array.withUnsafeMutableBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else {
                    throw ToolError(
                        "failed to prepare process argument storage",
                        exitCode: ToolExitCode.process)
                }
                return try body(baseAddress)
            }
        }
    #endif

    private func ignoreCleanupError(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            // Cleanup best-effort only.
        }
    }
}

// swiftlint:enable function_body_length type_body_length
