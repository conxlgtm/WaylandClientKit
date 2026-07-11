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

public struct DocumentationSymbolCoverageVerifier {
    private struct Graph: Decodable {
        struct Module: Decodable { let name: String }
        struct Symbol: Decodable {
            struct Kind: Decodable { let identifier: String }
            struct DocComment: Decodable {
                struct Line: Decodable { let text: String }
                let lines: [Line]
            }

            let kind: Kind
            let accessLevel: String
            let docComment: DocComment?
        }

        let module: Module
        let symbols: [Symbol]
    }

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
                Graph.self,
                from: Data(try fileSystem.readText(url).utf8)
            )
            for symbol in graph.symbols
            where symbol.accessLevel == "public"
                && Self.eligibleKinds.contains(symbol.kind.identifier)
            {
                totals[graph.module.name, default: (0, 0)].eligible += 1
                let hasAbstract =
                    symbol.docComment?.lines.contains {
                        !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    } ?? false
                if hasAbstract {
                    totals[graph.module.name, default: (0, 0)].documented += 1
                }
            }
        }
        return DocumentationSymbolCoverage(
            products: totals.mapValues {
                DocumentationSymbolCoverage.Product(
                    eligible: $0.eligible,
                    documented: $0.documented
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
            let text = String(decoding: try encoder.encode(current), as: UTF8.self) + "\n"
            try fileSystem.writeText(text, to: baseline)
            return
        }

        guard fileSystem.exists(baseline) else {
            throw ToolError(
                "Missing documentation symbol coverage baseline: docs/documentation-symbol-coverage.json",
                exitCode: ToolExitCode.data
            )
        }
        let saved = try JSONDecoder().decode(
            DocumentationSymbolCoverage.self,
            from: Data(try fileSystem.readText(baseline).utf8)
        )
        var failures: [String] = []
        for (name, previous) in saved.products.sorted(by: { $0.key < $1.key }) {
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
