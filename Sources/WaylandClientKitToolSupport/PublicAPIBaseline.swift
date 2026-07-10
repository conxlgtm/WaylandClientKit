import Foundation

public struct SemanticPublicAPIBaseline {
    public let fileSystem: FileSystem

    public init(fileSystem: FileSystem = LocalFileSystem()) {
        self.fileSystem = fileSystem
    }

    public func render(symbolGraphs: [URL]) throws -> String {
        let fragments = try symbolGraphs.map(loadModule)
        let modules = Dictionary(grouping: fragments, by: \.name).map { name, fragments in
            ModuleRecord(
                name: name,
                symbols: fragments.flatMap(\.symbols).sorted(),
                relationships: fragments.flatMap(\.relationships).sorted()
            )
        }.sorted { $0.name < $1.name }
        return modules.map(render).joined(separator: "\n")
    }

    private func loadModule(from url: URL) throws -> ModuleRecord {
        let value = try JSONSerialization.jsonObject(with: fileSystem.readData(url))
        guard let object = value as? [String: Any] else {
            throw ToolError(
                "Symbol graph root must be an object: \(url.path)",
                exitCode: ToolExitCode.data
            )
        }
        guard
            let module = object["module"] as? [String: Any],
            let moduleName = module["name"] as? String
        else {
            throw ToolError(
                "Symbol graph is missing its module name: \(url.path)",
                exitCode: ToolExitCode.data
            )
        }

        let symbols = try (object["symbols"] as? [[String: Any]] ?? []).map { symbol in
            try symbolRecord(moduleName: moduleName, symbol: symbol, source: url)
        }.sorted()
        let relationships = (object["relationships"] as? [[String: Any]] ?? [])
            .compactMap { relationship in
                relationshipRecord(moduleName: moduleName, relationship: relationship)
            }
            .sorted()
        return ModuleRecord(name: moduleName, symbols: symbols, relationships: relationships)
    }

    private func symbolRecord(
        moduleName: String,
        symbol: [String: Any],
        source: URL
    ) throws -> SymbolRecord {
        guard
            let identifier = symbol["identifier"] as? [String: Any],
            let preciseIdentifier = identifier["precise"] as? String,
            let kind = symbol["kind"] as? [String: Any],
            let kindIdentifier = kind["identifier"] as? String,
            let path = symbol["pathComponents"] as? [String],
            let fragments = symbol["declarationFragments"] as? [[String: Any]]
        else {
            throw ToolError(
                "Malformed public symbol in \(source.path)",
                exitCode: ToolExitCode.data
            )
        }

        let declaration = normalizedWhitespace(
            fragments.compactMap { $0["spelling"] as? String }.joined()
        )
        let details = try canonicalDetails(symbol)
        return SymbolRecord(
            module: moduleName,
            preciseIdentifier: preciseIdentifier,
            kind: kindIdentifier,
            path: path.joined(separator: "."),
            declaration: declaration,
            details: details
        )
    }

    private func relationshipRecord(
        moduleName: String,
        relationship: [String: Any]
    ) -> RelationshipRecord? {
        guard
            let kind = relationship["kind"] as? String,
            let source = relationship["source"] as? String,
            let target = relationship["target"] as? String
        else {
            return nil
        }
        return RelationshipRecord(
            module: moduleName,
            source: source,
            kind: kind,
            target: target,
            targetFallback: relationship["targetFallback"] as? String ?? "-"
        )
    }

    private func canonicalDetails(_ symbol: [String: Any]) throws -> String {
        var details: [String: Any] = [:]
        for key in ["availability", "swiftExtension", "swiftGenerics"] {
            if let value = symbol[key] {
                details[key] = value
            }
        }
        guard !details.isEmpty else { return "-" }
        let data = try JSONSerialization.data(withJSONObject: details, options: [.sortedKeys])
        return String(data: data, encoding: .utf8) ?? "-"
    }

    private func normalizedWhitespace(_ value: String) -> String {
        value.split { character in character.isWhitespace }.joined(separator: " ")
    }

    private func render(_ module: ModuleRecord) -> String {
        var lines = [
            "## `\(module.name)`",
            "",
            "### Symbols",
            "",
            "```text",
        ]
        lines.append(
            contentsOf: module.symbols.map { symbol in
                [
                    symbol.preciseIdentifier,
                    symbol.kind,
                    symbol.path,
                    symbol.declaration,
                    symbol.details,
                ].joined(separator: "\t")
            })
        lines.append(contentsOf: ["```", "", "### Relationships", "", "```text"])
        lines.append(
            contentsOf: module.relationships.map { relationship in
                [
                    relationship.source,
                    relationship.kind,
                    relationship.target,
                    relationship.targetFallback,
                ].joined(separator: "\t")
            })
        lines.append(contentsOf: ["```", ""])
        return lines.joined(separator: "\n")
    }
}

private struct ModuleRecord {
    let name: String
    let symbols: [SymbolRecord]
    let relationships: [RelationshipRecord]
}

private struct SymbolRecord: Comparable {
    let module: String
    let preciseIdentifier: String
    let kind: String
    let path: String
    let declaration: String
    let details: String

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.sortKey.lexicographicallyPrecedes(rhs.sortKey)
    }

    private var sortKey: [String] {
        [module, path, kind, preciseIdentifier, declaration, details]
    }
}

private struct RelationshipRecord: Comparable {
    let module: String
    let source: String
    let kind: String
    let target: String
    let targetFallback: String

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.sortKey.lexicographicallyPrecedes(rhs.sortKey)
    }

    private var sortKey: [String] {
        [module, source, kind, target, targetFallback]
    }
}
