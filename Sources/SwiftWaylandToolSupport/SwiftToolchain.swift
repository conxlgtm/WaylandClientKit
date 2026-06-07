import Foundation

public struct SwiftToolchain: Sendable {
    public let runner: ProcessRunner

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    public func swiftExecutable(environment: [String: String] = ProcessInfo.processInfo.environment)
        throws -> String
    {
        if let override = environment["SWIFT_BIN"], !override.isEmpty {
            return override
        }

        let swiftlyHome =
            environment["SWIFTLY_HOME"]
            ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".local/share/swiftly")
            .path
        let toolchains = URL(fileURLWithPath: swiftlyHome).appendingPathComponent("toolchains")
        do {
            let candidates = try LocalFileSystem().walk(toolchains, includingDirectories: false)
            let swiftCandidates =
                candidates
                .filter { $0.path.hasSuffix("/usr/bin/swift") }
                .map(\.path)
                .sorted()
            if let latest = swiftCandidates.last {
                return latest
            }
        } catch {
            // Swiftly is optional, so fall back to normal PATH lookup.
        }

        return "swift"
    }

    @discardableResult
    public func runSwift(
        _ arguments: [String],
        repository: Repository,
        environment overrides: [String: String] = [:],
        requireSuccess: Bool = true
    ) throws -> ProcessResult {
        let environment = swiftRuntimeEnvironment(overrides)
        return try runner.run(
            swiftExecutable(environment: runner.environment),
            swiftPMArguments(arguments, environment: environment),
            workingDirectory: repository.root,
            environment: environment,
            requireSuccess: requireSuccess
        )
    }

    public func swiftRuntimeEnvironment(_ overrides: [String: String] = [:]) -> [String: String] {
        var env = overrides
        let compat =
            runner.environment["SWIFT_COMPAT_LIBS"]
            ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".local/share/swift-compat-libs")
            .path
        if FileManager.default.fileExists(atPath: compat) {
            let existing = runner.environment["LD_LIBRARY_PATH"] ?? ""
            env["LD_LIBRARY_PATH"] = existing.isEmpty ? compat : "\(compat):\(existing)"
        }
        return env
    }

    public func version(repository: Repository) throws -> String {
        let result = try runSwift(["--version"], repository: repository)
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func swiftPMBuildRoot(
        repository: Repository,
        environment overrides: [String: String] = [:]
    ) -> URL {
        let environment = swiftRuntimeEnvironment(overrides)
        guard let scratchPath = swiftPMScratchPath(environment: environment) else {
            return repository.url(".build")
        }
        return URL(fileURLWithPath: scratchPath)
    }

    private func swiftPMArguments(_ arguments: [String], environment: [String: String]) -> [String]
    {
        guard
            let scratchPath = swiftPMScratchPath(environment: environment),
            !arguments.contains("--scratch-path"),
            let command = arguments.first,
            ["build", "package", "run", "test"].contains(command)
        else {
            return arguments
        }
        var scratchArguments = arguments
        scratchArguments.insert(contentsOf: ["--scratch-path", scratchPath], at: 1)
        return scratchArguments
    }

    private func swiftPMScratchPath(environment: [String: String]) -> String? {
        let scratchPath =
            environment["SWIFT_WAYLAND_SWIFTPM_SCRATCH"]
            ?? runner.environment["SWIFT_WAYLAND_SWIFTPM_SCRATCH"]
        guard let scratchPath, !scratchPath.isEmpty else {
            return nil
        }
        return scratchPath
    }
}
