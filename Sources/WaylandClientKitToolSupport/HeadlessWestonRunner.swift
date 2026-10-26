import Foundation
import Subprocess
import SystemPackage

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

public struct HeadlessWestonRunner {
    public static let requestProcessTimeoutEnvironmentKey =
        "WAYLAND_CLIENT_KIT_REQUEST_PROCESS_TIMEOUT_SECONDS"
    public static let defaultRequestProcessTimeoutSeconds: TimeInterval = 600

    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    // Keep child and compositor teardown ordered in one scope.
    // swiftlint:disable:next function_body_length
    public func run(command: [String], timeoutSeconds: TimeInterval? = nil) async throws {
        guard !command.isEmpty else {
            throw ToolError("headless smoke requires a child command", exitCode: ToolExitCode.usage)
        }
        let timeout =
            try timeoutSeconds
            ?? Self.requestProcessTimeoutSeconds(
                environment: context.runner.environment)
        let childCommand = try swiftPMCommandIfNeeded(command)
        let westonPath = try context.runner.executableURL(for: "weston").path
        let runtime = try context.fileSystem.createTemporaryDirectory(prefix: "swlrt")
        defer {
            do {
                try context.fileSystem.removeItem(runtime)
            } catch {
                // Runtime removal is best-effort after process teardown.
            }
        }
        let config = runtime.appendingPathComponent("config")
        try context.fileSystem.createDirectory(config)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: runtime.path)

        let socket = "w\(UUID().uuidString.prefix(8))"
        let westonLog = runtime.appendingPathComponent("weston.log")
        let westonProcessLog = runtime.appendingPathComponent("weston-process.log")
        let childLog = runtime.appendingPathComponent("child.log")
        var environment = context.runner.environment
        environment["XDG_RUNTIME_DIR"] = runtime.path
        environment["XDG_CONFIG_HOME"] = config.path
        environment["WAYLAND_DISPLAY"] = socket
        environment.removeValue(forKey: "WAYLAND_SOCKET")
        let childEnvironment = processEnvironment(environment)
        var westonOutput = try ProcessOutputFile(westonProcessLog)
        var childOutput = try ProcessOutputFile(childLog)
        let westonFD = westonOutput.descriptor
        let completion = HeadlessExecutionCompletion()
        // swiftlint:disable:next no_unstructured_task
        let weston = Task { @concurrent in
            do {
                let result = try await Subprocess.run(
                    .path(FilePath(westonPath)),
                    arguments: Arguments([
                        "--backend=headless-backend.so", "--socket=\(socket)", "--idle-time=0",
                        "--log=\(westonLog.path)",
                    ]),
                    environment: childEnvironment,
                    platformOptions: Self.platformOptions,
                    input: .currentStandardInput,
                    output: .fileDescriptor(westonFD, closeAfterSpawningProcess: false),
                    error: .combinedWithOutput)
                await completion.finish()
                return processExitCode(result.terminationStatus, shellSignalStatus: false)
            } catch {
                await completion.finish()
                throw processToolError(error, executable: "weston")
            }
        }
        var child: Task<Int32, any Error>?
        var failure: (any Error)?
        do {
            try await waitForSocket(
                runtime.appendingPathComponent(socket), completion: completion, weston: weston)
            try Task.checkCancellation()
            let childPath = try context.runner.executableURL(for: childCommand[0]).path
            let childFD = childOutput.descriptor
            let workingDirectory = FilePath(context.repository.root.path)
            // swiftlint:disable:next no_unstructured_task
            let execution = Task { @concurrent in
                do {
                    let result = try await Subprocess.run(
                        .path(FilePath(childPath)),
                        arguments: Arguments(Array(childCommand.dropFirst())),
                        environment: childEnvironment, workingDirectory: workingDirectory,
                        platformOptions: Self.platformOptions,
                        input: .currentStandardInput,
                        output: .fileDescriptor(childFD, closeAfterSpawningProcess: false),
                        error: .combinedWithOutput)
                    return processExitCode(result.terminationStatus, shellSignalStatus: false)
                } catch {
                    throw processToolError(error, executable: childCommand[0])
                }
            }
            child = execution
            let outcome = try await waitForChild(execution, timeoutSeconds: timeout)
            try Task.checkCancellation()
            if outcome.timedOut {
                throw ToolError(
                    "headless command timed out: \(childCommand.joined(separator: " "))",
                    exitCode: outcome.exitCode == 0 ? ToolExitCode.process : outcome.exitCode)
            }
            if outcome.exitCode != 0 {
                throw ToolError(
                    "headless command failed with exit code \(outcome.exitCode): "
                        + childCommand.joined(separator: " "), exitCode: outcome.exitCode)
            }
        } catch {
            failure = error
        }

        let westonResult = await settle(child: child, weston: weston)
        if failure == nil, case .failure(let error) = westonResult, !(error is CancellationError) {
            failure = error
        }
        if failure == nil, Task.isCancelled { failure = CancellationError() }
        closeOutput(&childOutput, failure: &failure)
        closeOutput(&westonOutput, failure: &failure)
        if let failure {
            printFailureLog(westonLog, label: "weston.log")
            printFailureLog(westonProcessLog, label: "weston process output")
            printFailureLog(childLog, label: "headless child output")
            throw failure
        }
    }

    private func settle(
        child: Task<Int32, any Error>?, weston: Task<Int32, any Error>
    ) async -> Result<Int32, any Error> {
        // Owned tasks do not inherit supervisor cancellation. Settle the child first.
        if let child {
            child.cancel()
            _ = await child.result
        }
        weston.cancel()
        return await weston.result
    }

    private func closeOutput(
        _ output: inout ProcessOutputFile, failure: inout (any Error)?
    ) {
        do {
            try output.close()
        } catch {
            if failure == nil { failure = processToolError(error, executable: "headless") }
        }
    }

    public static func requestProcessTimeoutSeconds(environment: [String: String]) throws
        -> TimeInterval
    {
        guard
            let raw = environment[requestProcessTimeoutEnvironmentKey]?
                .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty
        else { return defaultRequestProcessTimeoutSeconds }
        guard let value = TimeInterval(raw), value.isFinite, value > 0 else {
            throw ToolError(
                "invalid \(requestProcessTimeoutEnvironmentKey): expected positive seconds",
                exitCode: ToolExitCode.environment)
        }
        return value
    }

    public static func isUnixSocket(_ url: URL) -> Bool {
        var status = stat()
        guard lstat(url.path, &status) == 0 else { return false }
        return (status.st_mode & S_IFMT) == S_IFSOCK
    }

    private static var platformOptions: PlatformOptions {
        var options = PlatformOptions()
        options.teardownSequence = [
            .send(signal: .terminate, allowedDurationToNextStep: .seconds(5))
        ]
        return options
    }

    private func swiftPMCommandIfNeeded(_ command: [String]) throws -> [String] {
        guard command.first == "wck" else { return command }
        let swift = try context.swift.swiftExecutable(environment: context.runner.environment)
        return [swift, "run", "wck"] + command.dropFirst()
    }

    private func waitForSocket(
        _ socket: URL, completion: HeadlessExecutionCompletion, weston: Task<Int32, any Error>
    ) async throws {
        for _ in 0..<100 {
            try Task.checkCancellation()
            if await completion.finished {
                _ = try await weston.value
                throw ToolError(
                    "weston exited before creating \(socket.path)", exitCode: ToolExitCode.process)
            }
            if Self.isUnixSocket(socket) { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw ToolError("weston did not create \(socket.path)", exitCode: ToolExitCode.process)
    }

    private func waitForChild(_ child: Task<Int32, any Error>, timeoutSeconds: TimeInterval)
        async throws
        -> (exitCode: Int32, timedOut: Bool)
    {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                _ = try await child.value
                return false
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeoutSeconds))
                return true
            }
            do {
                let timedOut = try await group.next() ?? false
                if timedOut { child.cancel() }
                let exitCode: Int32
                do {
                    exitCode = try await child.value
                } catch is CancellationError {
                    guard timedOut else { throw CancellationError() }
                    exitCode = ToolExitCode.process
                }
                group.cancelAll()
                return (exitCode, timedOut)
            } catch {
                child.cancel()
                _ = await child.result
                group.cancelAll()
                throw error
            }
        }
    }

    private func printFailureLog(_ url: URL, label: String) {
        let text: String
        do {
            text = try context.fileSystem.readText(url)
        } catch {
            return
        }
        guard !text.isEmpty else { return }
        context.diagnostics.error("----- \(label) -----\n\(text)\n---------------------")
    }
}

private actor HeadlessExecutionCompletion {
    private(set) var finished = false

    func finish() {
        finished = true
    }
}
