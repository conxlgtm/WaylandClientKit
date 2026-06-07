import Foundation

public struct DocCVerifier {
    public struct Product: Sendable {
        public let moduleName: String
        public let catalogPath: String
        public let rootArticlePath: String

        public init(moduleName: String, catalogPath: String, rootArticlePath: String) {
            self.moduleName = moduleName
            self.catalogPath = catalogPath
            self.rootArticlePath = rootArticlePath
        }
    }

    public static let publicProducts = [
        Product(
            moduleName: "WaylandClient",
            catalogPath: "Sources/WaylandClient/WaylandClient.docc",
            rootArticlePath: "Sources/WaylandClient/WaylandClient.docc/WaylandClient.md"
        ),
        Product(
            moduleName: "WaylandGraphicsPreview",
            catalogPath: "Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc",
            rootArticlePath:
                "Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc/"
                + "WaylandGraphicsPreview.md"
        ),
    ]

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
        var failures: [String] = []
        for product in Self.publicProducts {
            let catalog = repository.url(product.catalogPath)
            let article = repository.url(product.rootArticlePath)
            if !fileSystem.isDirectory(catalog) {
                failures.append(
                    "Missing \(product.moduleName) DocC catalog: \(product.catalogPath)"
                )
            }
            if !fileSystem.exists(article) {
                failures.append(
                    "Missing \(product.moduleName) DocC article: \(product.rootArticlePath)"
                )
            }
        }
        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
    }

    public func verifySymbolLinks() throws {
        try verifyCatalogExists()
        var failures: [String] = []
        for product in Self.publicProducts {
            let graph = try requireSymbolGraph(for: product)
            let symbols = try symbolTitles(from: graph, moduleName: product.moduleName)
            let catalog = repository.url(product.catalogPath)
            failures.append(
                contentsOf: try symbolLinkFailures(
                    in: catalog,
                    symbols: symbols,
                    product: product)
            )
        }

        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }

        diagnostics.success("DocC symbol links resolve for public products")
    }

    private func symbolLinkFailures(
        in catalog: URL,
        symbols: Set<String>,
        product: Product
    ) throws -> [String] {
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
                                + "\(product.moduleName) "
                                + "unresolved DocC symbol link: \(link)"
                        )
                    }
                }
            }
        }

        return failures
    }

    public func removePublicProductSymbolGraphs() throws {
        for product in Self.publicProducts {
            for graph in try findSymbolGraphs(for: product.moduleName) {
                try fileSystem.removeItem(graph)
            }
        }
    }

    public func removeWaylandClientSymbolGraphs() throws {
        for graph in try findSymbolGraphs(for: "WaylandClient") {
            try fileSystem.removeItem(graph)
        }
    }

    public func requireWaylandClientSymbolGraph() throws -> URL {
        try requireSymbolGraph(for: "WaylandClient")
    }

    public func requirePublicProductSymbolGraphs(afterDump result: ProcessResult) throws {
        for product in Self.publicProducts {
            _ = try requireSymbolGraph(for: product, afterDump: result)
        }
    }

    private func requireSymbolGraph(for product: Product) throws -> URL {
        try requireSymbolGraph(for: product.moduleName)
    }

    private func requireSymbolGraph(for moduleName: String) throws -> URL {
        guard let graph = try findSymbolGraphs(for: moduleName).first else {
            throw ToolError(
                "Missing \(moduleName) symbol graph under \(buildRoot.path)/*/symbolgraph",
                exitCode: ToolExitCode.data
            )
        }
        return graph
    }

    public func requireWaylandClientSymbolGraph(afterDump result: ProcessResult) throws -> URL {
        try requireSymbolGraph(
            for: Self.publicProducts[0],
            afterDump: result
        )
    }

    private func requireSymbolGraph(
        for product: Product,
        afterDump result: ProcessResult
    ) throws -> URL {
        let graph: URL
        do {
            graph = try requireSymbolGraph(for: product)
        } catch {
            if result.exitCode != 0 {
                throw Self.symbolGraphDumpError(
                    result,
                    detail: "No fresh \(product.moduleName) symbol graph was emitted.")
            }
            throw error
        }

        if result.exitCode != 0 {
            throw Self.symbolGraphDumpError(
                result,
                detail:
                    "\(product.moduleName) symbol graph was emitted, "
                    + "but dump-symbol-graph failed.")
        }
        return graph
    }

    private func findSymbolGraphs(for moduleName: String) throws -> [URL] {
        try fileSystem.walk(buildRoot, includingDirectories: false)
            .filter { $0.path.hasSuffix("/symbolgraph/\(moduleName).symbols.json") }
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

    private func symbolTitles(from url: URL, moduleName: String) throws -> Set<String> {
        let object = try JSONHelpers.loadObject(from: url)
        var titles: Set<String> = [moduleName]
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
