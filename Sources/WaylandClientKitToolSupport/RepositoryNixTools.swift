import Foundation

struct RepositoryNixTools {
    let repository: Repository
    let fileSystem: FileSystem
    let runner: ProcessRunner
    let diagnostics: Diagnostics

    func executablePath(
        for executable: String,
        probeArguments: [String] = []
    ) throws -> String {
        if canRunPathTool(executable, probeArguments: probeArguments) {
            return try runner.executableURL(for: executable).path
        }

        if let nixPath = nixExecutablePath(for: executable, probeArguments: probeArguments) {
            return nixPath
        }

        return try runner.executableURL(for: executable).path
    }

    func canRunPathTool(_ executable: String, probeArguments: [String]) -> Bool {
        guard runner.canFind(executable) else {
            return false
        }

        guard !probeArguments.isEmpty else {
            return true
        }

        do {
            let result = try runner.run(
                executable,
                probeArguments,
                workingDirectory: repository.root,
                requireSuccess: false
            )
            return result.exitCode == 0
        } catch {
            return false
        }
    }

    func canRunInNix(
        _ executable: String,
        probeArguments: [String],
        requiresSwift: Bool,
        label: String
    ) -> Bool {
        guard hasFlake, let nixExecutable else {
            return false
        }

        do {
            let result = try runner.run(
                nixExecutable,
                nixArguments(command: executable, arguments: probeArguments),
                workingDirectory: repository.root,
                environment: nixEnvironment(requiresSwift: requiresSwift),
                requireSuccess: false
            )
            if result.exitCode != 0 {
                diagnostics.verbose(
                    "\(label) probe failed: "
                        + (result.stderr.isEmpty ? result.stdout : result.stderr))
            }
            return result.exitCode == 0
        } catch {
            diagnostics.verbose("\(label) probe failed: \(error)")
            return false
        }
    }

    func runInNix(
        _ executable: String,
        _ arguments: [String],
        requiresSwift: Bool
    ) throws {
        guard let nixExecutable else {
            try runner.run(
                "nix",
                nixArguments(command: executable, arguments: arguments),
                workingDirectory: repository.root,
                environment: nixEnvironment(requiresSwift: requiresSwift)
            )
            return
        }

        try runner.run(
            nixExecutable,
            nixArguments(command: executable, arguments: arguments),
            workingDirectory: repository.root,
            environment: nixEnvironment(requiresSwift: requiresSwift)
        )
    }

    private var hasFlake: Bool {
        fileSystem.exists(repository.url("flake.nix"))
    }

    private var nixExecutable: String? {
        if let override = runner.environment["SWL_NIX_BIN"], !override.isEmpty {
            return override
        }

        if runner.canFind("nix") {
            return "nix"
        }

        let nixOSPath = URL(fileURLWithPath: "/run/current-system/sw/bin/nix")
        if fileSystem.isExecutable(nixOSPath) {
            return nixOSPath.path
        }

        return nil
    }

    private func nixExecutablePath(
        for executable: String,
        probeArguments: [String]
    ) -> String? {
        guard hasFlake, let nixExecutable else {
            return nil
        }

        do {
            let result = try runner.run(
                nixExecutable,
                nixCommandLookupArguments(executable),
                workingDirectory: repository.root,
                environment: nixEnvironment(requiresSwift: false),
                requireSuccess: false
            )
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            guard result.exitCode == 0, !path.isEmpty else {
                diagnostics.verbose(
                    "flake \(executable) lookup failed: "
                        + (result.stderr.isEmpty ? result.stdout : result.stderr))
                return nil
            }
            guard fileSystem.isExecutable(URL(fileURLWithPath: path)) else {
                diagnostics.verbose("flake \(executable) lookup returned non-executable: \(path)")
                return nil
            }
            guard canRunResolvedTool(path, probeArguments: probeArguments) else {
                diagnostics.verbose("flake \(executable) resolved path failed probe: \(path)")
                return nil
            }
            return path
        } catch {
            diagnostics.verbose("flake \(executable) lookup failed: \(error)")
            return nil
        }
    }

    private func canRunResolvedTool(_ executable: String, probeArguments: [String]) -> Bool {
        guard !probeArguments.isEmpty else {
            return true
        }

        do {
            let result = try runner.run(
                executable,
                probeArguments,
                workingDirectory: repository.root,
                requireSuccess: false
            )
            return result.exitCode == 0
        } catch {
            return false
        }
    }

    private func nixCommandLookupArguments(_ executable: String) -> [String] {
        [
            "--option", "warn-dirty", "false", "develop", repository.root.path,
            "--command", "sh", "-c", "command -v \"$1\"", "sh", executable,
        ]
    }

    private func nixArguments(command: String, arguments: [String]) -> [String] {
        [
            "--option", "warn-dirty", "false", "develop", repository.root.path,
            "--command", command,
        ] + arguments
    }

    private func nixEnvironment(requiresSwift: Bool) -> [String: String] {
        // The repo flake probes Swift while entering the dev shell, even for non-Swift tools.
        guard requiresSwift || hasFlake else {
            return [:]
        }

        if let override = runner.environment["SWIFT_BIN"], !override.isEmpty {
            return ["SWIFT_BIN": override]
        }

        let nixOSSwift = URL(fileURLWithPath: "/run/current-system/sw/bin/swift")
        if fileSystem.isExecutable(nixOSSwift) {
            return ["SWIFT_BIN": nixOSSwift.path]
        }

        do {
            return ["SWIFT_BIN": try runner.executableURL(for: "swift").path]
        } catch {
            return [:]
        }
    }
}
