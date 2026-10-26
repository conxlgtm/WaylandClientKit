import Foundation
import Subprocess
import SystemPackage

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
    ) async throws -> ProcessResult {
        diagnostics.verbose("running \(([executable] + arguments).joined(separator: " "))")
        let executablePath = try executableURL(for: executable).path
        let outputDirectory: URL
        do {
            outputDirectory = try temporaryOutputDirectory()
        } catch {
            throw ToolError(
                "failed to create process output directory: \(error)",
                exitCode: ToolExitCode.environment)
        }
        defer { ignoreCleanupError { try FileManager.default.removeItem(at: outputDirectory) } }

        do {
            var stdout = try ProcessOutputFile(outputDirectory.appendingPathComponent("stdout"))
            var stderr = try ProcessOutputFile(outputDirectory.appendingPathComponent("stderr"))
            let execution = try await Subprocess.run(
                .path(FilePath(executablePath)),
                arguments: Arguments(arguments),
                environment: processEnvironment(mergedEnvironment(overrides)),
                workingDirectory: workingDirectory.map { FilePath($0.path) },
                input: .currentStandardInput,
                output: .fileDescriptor(stdout.descriptor, closeAfterSpawningProcess: false),
                error: .fileDescriptor(stderr.descriptor, closeAfterSpawningProcess: false))
            try stdout.close()
            try stderr.close()
            let result = ProcessResult(
                executable: executable,
                arguments: arguments,
                exitCode: processExitCode(execution.terminationStatus),
                stdout: try stdout.readText(),
                stderr: try stderr.readText())
            if requireSuccess, result.exitCode != 0 {
                throw ToolError(
                    """
                    command failed with exit code \(result.exitCode): \(result.commandLine)
                    \(failureDetails(for: result))
                    """,
                    exitCode: ToolExitCode.process)
            }
            return result
        } catch {
            throw processToolError(error, executable: executable)
        }
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
            .appendingPathComponent("waylandclientkit-process.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func failureDetails(for result: ProcessResult) -> String {
        var sections: [String] = []
        if !result.stdout.isEmpty {
            sections.append("standard output:\n\(result.stdout)")
        }
        if !result.stderr.isEmpty {
            sections.append("standard error:\n\(result.stderr)")
        }
        return sections.joined(separator: "\n")
    }

    private func ignoreCleanupError(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            // Capture cleanup must not replace the command result.
        }
    }
}

func processEnvironment(_ values: [String: String]) -> Environment {
    .custom(
        values.reduce(into: [Environment.Key: String]()) { result, entry in
            result[Environment.Key(stringLiteral: entry.key)] = entry.value
        })
}

func processExitCode(_ status: TerminationStatus, shellSignalStatus: Bool = true) -> Int32 {
    switch status {
    case .exited(let code):
        return code
    case .signaled(let signal):
        #if os(Linux)
            return shellSignalStatus ? 128 + signal : signal
        #else
            return signal
        #endif
    }
}

func processToolError(_ error: any Error, executable: String) -> any Error {
    if error is ToolError || error is CancellationError { return error }
    if let error = error as? SubprocessError {
        return ToolError(
            "failed to run \(executable): \(error)",
            exitCode: error.code == .failedToChangeWorkingDirectory
                ? ToolExitCode.environment : ToolExitCode.process)
    }
    return ToolError(
        "process I/O failed for \(executable): \(error)", exitCode: ToolExitCode.environment)
}

struct ProcessOutputFile: ~Copyable {
    let url: URL
    private var openDescriptor: FileDescriptor?

    init(_ url: URL) throws {
        self.url = url
        do {
            self.openDescriptor = try FileDescriptor.open(
                FilePath(url.path), .writeOnly, options: [.create, .truncate, .closeOnExec],
                permissions: [.ownerRead, .ownerWrite])
        } catch {
            throw ToolError(
                "failed to open process output file \(url.path): \(error)",
                exitCode: ToolExitCode.environment)
        }
    }

    var descriptor: FileDescriptor {
        guard let openDescriptor else {
            preconditionFailure("process output descriptor is closed")
        }
        return openDescriptor
    }

    mutating func close() throws {
        if let descriptor = openDescriptor.take() {
            try descriptor.close()
        }
    }

    func readText() throws -> String {
        String(data: try Data(contentsOf: url), encoding: .utf8) ?? ""
    }

    deinit {
        if let descriptor = openDescriptor {
            do {
                try descriptor.close()
            } catch {
                // Explicit close reports errors; destruction is best-effort.
            }
        }
    }
}
