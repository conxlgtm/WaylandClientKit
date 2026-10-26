import Foundation

/// Finds build artifacts only in SwiftPM's selected products directory.
public struct SwiftBuildArtifacts {
    public let buildRoot: URL
    public let productsDirectory: URL
    public let fileSystem: FileSystem

    public init(
        buildRoot: URL, productsDirectory: URL, fileSystem: FileSystem = LocalFileSystem()
    ) throws {
        self.buildRoot = buildRoot.resolvingSymlinksInPath().standardizedFileURL
        self.productsDirectory = productsDirectory.resolvingSymlinksInPath().standardizedFileURL
        self.fileSystem = fileSystem
        guard self.productsDirectory.path.hasPrefix(self.buildRoot.path + "/") else {
            throw ToolError(
                "Build products are outside selected scratch tree: \(productsDirectory.path)",
                exitCode: ToolExitCode.data)
        }
    }

    public func testRunners() throws -> [URL] {
        let runners = try fileSystem.walk(productsDirectory, includingDirectories: false)
            .filter { executable in
                executable.deletingLastPathComponent().path == productsDirectory.path
                    && executable.lastPathComponent.hasSuffix("-test-runner")
                    && fileSystem.isExecutable(executable)
            }
            .sorted { $0.path < $1.path }
        guard !runners.isEmpty else {
            throw ToolError(
                "No test runners were found in \(productsDirectory.path)",
                exitCode: ToolExitCode.data)
        }
        return runners
    }

    private var coverageProfile: URL {
        productsDirectory.appendingPathComponent("wck-coverage.profdata")
    }

    public func resetCoverage() throws {
        try fileSystem.removeItem(coverageProfile)
        try fileSystem.removeItem(productsDirectory.appendingPathComponent("codecov"))
        for executable in try fileSystem.walk(productsDirectory, includingDirectories: false)
        where executable.deletingLastPathComponent().path == productsDirectory.path
            && executable.lastPathComponent.hasSuffix("-test-runner")
        {
            try fileSystem.removeItem(executable)
        }
    }

    public func accumulateCoverage(swift: SwiftToolchain, repository: Repository) async throws {
        let coverageRoot = productsDirectory.appendingPathComponent("codecov")
        let profiles = try fileSystem.walk(coverageRoot, includingDirectories: false)
            .filter { $0.pathExtension == "profraw" }.sorted { $0.path < $1.path }
        guard !profiles.isEmpty else {
            throw ToolError(
                "No raw coverage profiles in \(coverageRoot.path)", exitCode: ToolExitCode.data)
        }
        let tool = URL(
            fileURLWithPath: try swift.swiftCompilerExecutable(
                environment: swift.runner.environment)
        ).deletingLastPathComponent().appendingPathComponent("llvm-profdata")
        var inputs = profiles.map(\.path)
        if fileSystem.exists(coverageProfile) { inputs.append(coverageProfile.path) }
        // SwiftPM replaces codecov on each test invocation, including filtered runs.
        try await swift.runSwiftTool(
            tool.path, ["merge", "-sparse"] + inputs + ["-o", coverageProfile.path],
            repository: repository)
    }

    public func exportCoverage(
        swift: SwiftToolchain, repository: Repository
    ) async throws {
        let coverageRoot = productsDirectory.appendingPathComponent("codecov")
        let files = try fileSystem.walk(coverageRoot, includingDirectories: false)
        guard fileSystem.exists(coverageProfile) else {
            throw ToolError(
                "No accumulated coverage profile at \(coverageProfile.path)",
                exitCode: ToolExitCode.data)
        }
        let tools = URL(
            fileURLWithPath: try swift.swiftCompilerExecutable(
                environment: swift.runner.environment)
        ).deletingLastPathComponent()
        // LLVM combines all objects before computing source and function totals.
        var arguments = ["export", "-instr-profile=\(coverageProfile.path)"]
        for (index, executable) in try testRunners().enumerated() {
            let name = String(executable.lastPathComponent.dropLast("-test-runner".count))
            let bundle = productsDirectory.appendingPathComponent(name + ".so")
            guard fileSystem.exists(bundle) else {
                throw ToolError(
                    "Missing coverage test bundle: \(bundle.path)", exitCode: ToolExitCode.data)
            }
            if index > 0 { arguments.append("-object") }
            arguments.append(bundle.path)
        }
        let result = try await swift.runSwiftTool(
            tools.appendingPathComponent("llvm-cov").path, arguments, repository: repository)
        for file in files where file.pathExtension == "json" {
            try fileSystem.removeItem(file)
        }
        try fileSystem.writeText(
            result.stdout, to: coverageRoot.appendingPathComponent("all-targets.json"))
    }

    public func runThreadSanitizerTests(
        runner: ProcessRunner, repository: Repository,
        environment: [String: String], filters: [String]
    ) async throws {
        let architecture = try await runner.run("uname", ["-m"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let expressions = try filters.map { try Regex($0) }
        var matchedFilters = Set<Int>()
        var failures: [String] = []
        for executable in try testRunners() {
            var tests: [Substring] = []
            if !filters.isEmpty {
                do {
                    let listing = try await runner.run(
                        "setarch",
                        [
                            architecture, "-R", executable.path, "--list-tests",
                            "--testing-library", "swift-testing",
                        ],
                        workingDirectory: repository.root, environment: environment)
                    tests = listing.stdout.split(separator: "\n")
                } catch {
                    failures.append(String(describing: error))
                    continue
                }
            }
            for index in 0..<max(1, filters.count) {
                let filter = filters.isEmpty ? nil : filters[index]
                if filter != nil {
                    guard tests.contains(where: { $0.firstMatch(of: expressions[index]) != nil })
                    else { continue }
                    matchedFilters.insert(index)
                }
                var arguments = ["--sanitize=thread", "--no-parallel"]
                if let filter { arguments.append(contentsOf: ["--filter", filter]) }
                arguments.append(contentsOf: ["--testing-library", "swift-testing"])
                do {
                    try await runner.run(
                        "setarch", [architecture, "-R", executable.path] + arguments,
                        workingDirectory: repository.root, environment: environment)
                } catch {
                    failures.append(String(describing: error))
                }
            }
        }
        for (index, filter) in filters.enumerated() where !matchedFilters.contains(index) {
            failures.append("No test target matches filter: \(filter)")
        }
        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.process)
        }
    }

    public func releaseObjects(target: String) throws -> [URL] {
        let configuration = productsDirectory.lastPathComponent
        guard configuration.hasPrefix("Release-") else {
            throw ToolError(
                "Expected Swift Build release products, got \(productsDirectory.path)",
                exitCode: ToolExitCode.data)
        }
        let intermediates = productsDirectory.deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Intermediates.noindex")
        let lists = try fileSystem.walk(intermediates, includingDirectories: false)
            .filter { url in
                url.lastPathComponent == "\(target).LinkFileList"
                    && url.pathComponents.contains(configuration)
                    && url.pathComponents.contains("\(target)-t.build")
                    && url.pathComponents.contains("Objects-normal")
            }
        guard lists.count == 1, let list = lists.first else {
            throw ToolError(
                "Missing or ambiguous release object list for \(target) in \(buildRoot.path)",
                exitCode: ToolExitCode.data)
        }
        let objectRoot = list.deletingLastPathComponent().resolvingSymlinksInPath().path + "/"
        let objects = try fileSystem.readText(list).split(separator: "\n").map { line in
            URL(fileURLWithPath: String(line)).resolvingSymlinksInPath()
        }
        guard
            objects.allSatisfy({ object in
                object.path.hasPrefix(objectRoot) && object.pathExtension == "o"
                    && fileSystem.exists(object)
            })
        else {
            throw ToolError(
                "Missing or out-of-tree release object for \(target): \(list.path)",
                exitCode: ToolExitCode.data)
        }
        guard !objects.isEmpty else {
            throw ToolError(
                "No release objects for \(target) in selected build tree \(buildRoot.path)",
                exitCode: ToolExitCode.data)
        }
        return objects
    }
}
