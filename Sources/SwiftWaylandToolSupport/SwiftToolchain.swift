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
        if let candidates = try? LocalFileSystem().walk(toolchains, includingDirectories: false) {
            let swiftCandidates =
                candidates
                .filter { $0.path.hasSuffix("/usr/bin/swift") }
                .map(\.path)
                .sorted()
            if let latest = swiftCandidates.last {
                return latest
            }
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
        try runner.run(
            swiftExecutable(environment: runner.environment),
            arguments,
            workingDirectory: repository.root,
            environment: swiftRuntimeEnvironment(overrides),
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
}
