import Foundation

public enum CCompilerFilter {
    public static let modeEnvironmentKey = "WAYLAND_CLIENT_KIT_C_COMPILER_FILTER"
    public static let realCompilerEnvironmentKey = "WAYLAND_CLIENT_KIT_REAL_CC"

    public static func isEnabled(environment: [String: String]) -> Bool {
        environment[modeEnvironmentKey] == "1"
    }

    public static func compilerEnvironment(
        filterExecutable: URL,
        base: [String: String],
        inherited: [String: String]
    ) -> [String: String] {
        let filterPath = filterExecutable.standardizedFileURL.path
        var environment = base
        environment[modeEnvironmentKey] = "1"
        if environment[realCompilerEnvironmentKey]?.isEmpty != false {
            let compiler = environment["CC"] ?? inherited["CC"]
            if let compiler, !compiler.isEmpty, compiler != filterPath {
                environment[realCompilerEnvironmentKey] = compiler
            }
        }
        environment["CC"] = filterPath
        return environment
    }

    public static func run(
        arguments: [String],
        environment: [String: String]
    ) throws -> ProcessResult {
        let compiler = try resolveCompiler(environment: environment)
        return try ProcessRunner(environment: environment).run(
            compiler,
            filteredArguments(arguments),
            requireSuccess: false)
    }

    public static func filterExecutableURL(
        commandPath: String,
        workingDirectory: URL,
        runner: ProcessRunner
    ) throws -> URL {
        guard !commandPath.isEmpty else {
            throw ToolError(
                "cannot resolve swl executable path",
                exitCode: ToolExitCode.environment)
        }
        if commandPath.hasPrefix("/") {
            return URL(fileURLWithPath: commandPath).standardizedFileURL
        }
        if commandPath.contains("/") {
            return workingDirectory.appendingPathComponent(commandPath).standardizedFileURL
        }
        return try runner.executableURL(for: commandPath).standardizedFileURL
    }

    public static func filteredArguments(_ arguments: [String]) -> [String] {
        var filtered: [String] = []
        var skipNext = false
        for argument in arguments {
            if skipNext {
                skipNext = false
                continue
            }

            switch argument {
            case "-index-store-path", "-index-unit-output-path":
                skipNext = true
            case let value
            where value.hasPrefix("-index-store-path=")
                || value.hasPrefix("-index-unit-output-path="):
                continue
            default:
                filtered.append(argument)
            }
        }
        return filtered
    }

    private static func resolveCompiler(environment: [String: String]) throws -> String {
        if let override = environment[realCompilerEnvironmentKey], !override.isEmpty {
            return override
        }

        let fileSystem = LocalFileSystem()
        if let swift = environment["SWIFT_BIN"], !swift.isEmpty {
            let clang = URL(fileURLWithPath: swift)
                .deletingLastPathComponent()
                .appendingPathComponent("clang")
            if fileSystem.isExecutable(clang) {
                return clang.path
            }
        }

        let swiftlyHome =
            environment["SWIFTLY_HOME"]
            ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".local/share/swiftly")
            .path
        let toolchains = URL(fileURLWithPath: swiftlyHome).appendingPathComponent("toolchains")
        if fileSystem.exists(toolchains) {
            let clang = try fileSystem.walk(toolchains, includingDirectories: false)
                .filter { $0.path.hasSuffix("/usr/bin/clang") && fileSystem.isExecutable($0) }
                .map(\.path)
                .max()
            if let clang {
                return clang
            }
        }

        let runner = ProcessRunner(environment: environment)
        if runner.canFind("clang") {
            return "clang"
        }
        _ = try runner.executableURL(for: "cc")
        return "cc"
    }
}
