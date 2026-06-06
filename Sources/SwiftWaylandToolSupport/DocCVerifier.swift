import Foundation

public struct DocCVerifier {
    public let repository: Repository
    public let buildRoot: URL
    public let fileSystem: FileSystem
    public let diagnostics: Diagnostics

    public init(
        repository: Repository,
        buildRoot: URL? = nil,
        fileSystem: FileSystem = LocalFileSystem(),
        diagnostics: Diagnostics = Diagnostics()
    ) {
        self.repository = repository
        self.buildRoot = (buildRoot ?? repository.url(".build")).standardizedFileURL
        self.fileSystem = fileSystem
        self.diagnostics = diagnostics
    }

    public func verifyCatalogExists() throws {
        let catalog = repository.url("Sources/WaylandClient/WaylandClient.docc")
        let article = catalog.appendingPathComponent("WaylandClient.md")
        var failures: [String] = []
        if !fileSystem.isDirectory(catalog) {
            failures.append("Missing DocC catalog: Sources/WaylandClient/WaylandClient.docc")
        }
        if !fileSystem.exists(article) {
            failures.append(
                "Missing DocC article: Sources/WaylandClient/WaylandClient.docc/WaylandClient.md")
        }
        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
    }

    public func verifySymbolLinks() throws {
        try verifyCatalogExists()
        let graph = try requireWaylandClientSymbolGraph()
        let symbols = try symbolTitles(from: graph)
        let catalog = repository.url("Sources/WaylandClient/WaylandClient.docc")
        let markdownFiles = try fileSystem.walk(catalog, includingDirectories: false)
            .filter { $0.pathExtension == "md" }
        let regex = try NSRegularExpression(pattern: #"``([^`\n]+)``"#)
        var failures: [String] = []

        for file in markdownFiles {
            let text = try fileSystem.readText(file)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(
                String.init)
            for (index, line) in lines.enumerated() {
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                for match in regex.matches(in: line, range: range) {
                    guard let swiftRange = Range(match.range(at: 1), in: line) else { continue }
                    let link = String(line[swiftRange])
                    let name = link.split(separator: "/").last.map(String.init) ?? link
                    if !symbols.contains(name) {
                        failures.append(
                            "\(repository.relativePath(file)):\(index + 1): "
                                + "unresolved DocC symbol link: \(link)"
                        )
                    }
                }
            }
        }

        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }

        diagnostics.success("DocC symbol links resolve against the public symbol graph")
    }

    public func removeWaylandClientSymbolGraphs() throws {
        for graph in try findWaylandClientSymbolGraphs() {
            try fileSystem.removeItem(graph)
        }
    }

    public func requireWaylandClientSymbolGraph() throws -> URL {
        guard let graph = try findWaylandClientSymbolGraphs().first else {
            throw ToolError(
                "Missing WaylandClient symbol graph under \(buildRoot.path)/*/symbolgraph",
                exitCode: ToolExitCode.data
            )
        }
        return graph
    }

    public func requireWaylandClientSymbolGraph(afterDump result: ProcessResult) throws -> URL {
        let graph: URL
        do {
            graph = try requireWaylandClientSymbolGraph()
        } catch {
            if result.exitCode != 0 {
                throw Self.symbolGraphDumpError(
                    result,
                    detail: "No fresh WaylandClient symbol graph was emitted.")
            }
            throw error
        }

        if result.exitCode != 0 {
            throw Self.symbolGraphDumpError(
                result,
                detail: "WaylandClient symbol graph was emitted, but dump-symbol-graph failed.")
        }
        return graph
    }

    private func findWaylandClientSymbolGraphs() throws -> [URL] {
        try fileSystem.walk(buildRoot, includingDirectories: false)
            .filter { $0.path.hasSuffix("/symbolgraph/WaylandClient.symbols.json") }
    }

    private static func symbolGraphDumpError(_ result: ProcessResult, detail: String) -> ToolError {
        ToolError(
            """
            command failed with exit code \(result.exitCode): \(result.commandLine)
            \(result.stderr.isEmpty ? result.stdout : result.stderr)
            \(detail)
            """,
            exitCode: ToolExitCode.process
        )
    }

    private func symbolTitles(from url: URL) throws -> Set<String> {
        let object = try JSONHelpers.loadObject(from: url)
        var titles: Set<String> = ["WaylandClient"]
        guard let symbols = object["symbols"] as? [[String: Any]] else { return titles }
        for symbol in symbols {
            guard
                let names = symbol["names"] as? [String: Any],
                let title = names["title"] as? String
            else {
                continue
            }
            titles.insert(title)
            if title.hasSuffix("()") {
                titles.insert(String(title.dropLast(2)))
            }
        }
        return titles
    }
}
