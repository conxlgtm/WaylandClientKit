import Foundation

public struct ProcessResult: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

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
    ) throws -> ProcessResult {
        diagnostics.verbose("running \(([executable] + arguments).joined(separator: " "))")

        let process = Process()
        process.executableURL = try executableURL(for: executable)
        process.arguments = arguments
        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }
        process.environment = mergedEnvironment(overrides)

        let stdout = Pipe()
        let stderr = Pipe()
        let stdoutBuffer = ProcessOutputBuffer()
        let stderrBuffer = ProcessOutputBuffer()
        process.standardOutput = stdout
        process.standardError = stderr
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                stdoutBuffer.append(data)
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                stderrBuffer.append(data)
            }
        }
        defer {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
        }

        try process.run()
        process.waitUntilExit()
        stdoutBuffer.append(stdout.fileHandleForReading.readDataToEndOfFile())
        stderrBuffer.append(stderr.fileHandleForReading.readDataToEndOfFile())

        let result = ProcessResult(
            executable: executable,
            arguments: arguments,
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutBuffer.data, encoding: .utf8) ?? "",
            stderr: String(data: stderrBuffer.data, encoding: .utf8) ?? ""
        )

        if requireSuccess && result.exitCode != 0 {
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

    public func executableURL(for executable: String) throws -> URL {
        if executable.contains("/") {
            let url = URL(fileURLWithPath: executable)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
            throw ToolError("executable is not runnable: \(executable)", exitCode: ToolExitCode.environment)
        }

        for directory in pathDirectories() {
            let candidate = directory.appendingPathComponent(executable)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        throw ToolError("executable not found on PATH: \(executable)", exitCode: ToolExitCode.environment)
    }

    public func canFind(_ executable: String) -> Bool {
        (try? executableURL(for: executable)) != nil
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
}

// SAFETY: storage is private and every read/write is serialized by lock.
private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.withLock { storage }
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.withLock {
            storage.append(data)
        }
    }
}
