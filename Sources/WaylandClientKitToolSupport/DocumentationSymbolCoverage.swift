import Foundation

public struct DocumentationSymbolCoverage: Codable, Equatable, Sendable {
    public struct Product: Codable, Equatable, Sendable {
        public let eligible: Int
        public let documented: Int

        public init(eligible: Int, documented: Int) {
            self.eligible = eligible
            self.documented = documented
        }
    }

    public let products: [String: Product]

    public init(products: [String: Product]) {
        self.products = products
    }
}

private struct DocumentationSymbolGraphModule: Decodable { let name: String }
private struct DocumentationSymbolKind: Decodable { let identifier: String }
private struct DocumentationSymbolDocLine: Decodable { let text: String }
private struct DocumentationSymbolDocComment: Decodable {
    let lines: [DocumentationSymbolDocLine]
}
private struct DocumentationSymbol: Decodable {
    let kind: DocumentationSymbolKind
    let accessLevel: String
    let docComment: DocumentationSymbolDocComment?
}
private struct DocumentationSymbolGraph: Decodable {
    let module: DocumentationSymbolGraphModule
    let symbols: [DocumentationSymbol]
}

public struct DocumentationSymbolCoverageVerifier {
    private static let eligibleKinds: Set<String> = [
        "swift.class", "swift.enum", "swift.struct", "swift.protocol",
        "swift.init", "swift.method", "swift.type.method", "swift.func.op",
        "swift.enum.case",
    ]

    public let fileSystem: FileSystem

    public init(fileSystem: FileSystem = LocalFileSystem()) {
        self.fileSystem = fileSystem
    }

    public func measure(symbolGraphs: [URL]) throws -> DocumentationSymbolCoverage {
        var totals: [String: (eligible: Int, documented: Int)] = [:]
        for url in symbolGraphs {
            let graph = try JSONDecoder().decode(
                DocumentationSymbolGraph.self,
                from: Data(try fileSystem.readText(url).utf8)
            )
            for symbol in graph.symbols
            where symbol.accessLevel == "public"
                && Self.eligibleKinds.contains(symbol.kind.identifier)
            {
                totals[graph.module.name, default: (0, 0)].eligible += 1
                let hasAbstract =
                    symbol.docComment?.lines.contains { line in
                        !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    } ?? false
                if hasAbstract {
                    totals[graph.module.name, default: (0, 0)].documented += 1
                }
            }
        }
        return DocumentationSymbolCoverage(
            products: totals.mapValues { total in
                DocumentationSymbolCoverage.Product(
                    eligible: total.eligible,
                    documented: total.documented
                )
            }
        )
    }

    public func verify(
        symbolGraphs: [URL],
        baseline: URL,
        update: Bool
    ) throws {
        let current = try measure(symbolGraphs: symbolGraphs)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if update {
            let data = try encoder.encode(current)
            guard let encoded = String(bytes: data, encoding: .utf8) else {
                throw ToolError("Could not encode documentation coverage as UTF-8")
            }
            let text = encoded + "\n"
            try fileSystem.writeText(text, to: baseline)
            return
        }

        guard fileSystem.exists(baseline) else {
            throw ToolError(
                "Missing documentation symbol coverage baseline: "
                    + "docs/documentation-symbol-coverage.json",
                exitCode: ToolExitCode.data
            )
        }
        let saved = try JSONDecoder().decode(
            DocumentationSymbolCoverage.self,
            from: Data(try fileSystem.readText(baseline).utf8)
        )
        var failures: [String] = []
        for (name, previous) in saved.products.sorted(by: { first, second in
            first.key < second.key
        }) {
            guard let now = current.products[name] else {
                failures.append("Missing documentation coverage for product \(name)")
                continue
            }
            if now.documented * previous.eligible < previous.documented * now.eligible {
                failures.append(
                    "\(name) symbol documentation coverage regressed from "
                        + "\(previous.documented)/\(previous.eligible) to "
                        + "\(now.documented)/\(now.eligible)"
                )
            }
        }
        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
    }
}
