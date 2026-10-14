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

    public func swiftCompilerExecutable(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> String {
        let selectedSwift = try swiftExecutable(environment: environment)
        let resolvedSwift =
            if selectedSwift.contains("/") {
                URL(fileURLWithPath: selectedSwift)
            } else {
                try runner.executableURL(for: selectedSwift)
            }
        return resolvedSwift.deletingLastPathComponent().appendingPathComponent("swiftc").path
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

    @discardableResult
    public func runSwiftTool(
        _ executable: String,
        _ arguments: [String],
        repository: Repository,
        requireSuccess: Bool = true
    ) throws -> ProcessResult {
        if let loader = runner.environment["WAYLAND_CLIENT_KIT_SWIFT_TOOL_LOADER"],
            let libraries = runner.environment["WAYLAND_CLIENT_KIT_SWIFT_TOOL_LIBRARIES"]
        {
            let tool = try runner.executableURL(for: executable)
            let file = try FileHandle(forReadingFrom: tool)
            let header = try file.read(upToCount: 4)
            try file.close()
            // Use the loader for ELF tools; scripts keep their own interpreters.
            if header?.starts(with: "\u{7f}ELF".utf8) == true {
                return try runner.run(
                    loader,
                    ["--library-path", libraries, "--argv0", tool.path, tool.path] + arguments,
                    workingDirectory: repository.root, requireSuccess: requireSuccess)
            }
        }
        return try runner.run(
            executable, arguments, workingDirectory: repository.root,
            environment: swiftRuntimeEnvironment(), requireSuccess: requireSuccess)
    }

    public func swiftRuntimeEnvironment(_ overrides: [String: String] = [:]) -> [String: String] {
        var env = overrides
        if runner.environment["WAYLAND_CLIENT_KIT_SWIFT_TOOL_LOADER"] != nil {
            return env
        }
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
            environment["WAYLAND_CLIENT_KIT_SWIFTPM_SCRATCH"]
            ?? runner.environment["WAYLAND_CLIENT_KIT_SWIFTPM_SCRATCH"]
        guard let scratchPath, !scratchPath.isEmpty else {
            return nil
        }
        return scratchPath
    }
}
