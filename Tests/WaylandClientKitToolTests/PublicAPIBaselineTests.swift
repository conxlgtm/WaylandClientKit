import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct PublicAPIBaselineTests {
    @Test
    func capturesContinuationLineChangesButIgnoresLocations() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-api-baseline-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = root.appendingPathComponent("original.symbols.json")
        let changed = root.appendingPathComponent("changed.symbols.json")
        let relocated = root.appendingPathComponent("relocated.symbols.json")
        try semanticSymbolGraph(parameterType: "Int", line: 10).write(
            to: original,
            atomically: true,
            encoding: .utf8
        )
        try semanticSymbolGraph(parameterType: "String", line: 10).write(
            to: changed,
            atomically: true,
            encoding: .utf8
        )
        try semanticSymbolGraph(parameterType: "Int", line: 200).write(
            to: relocated,
            atomically: true,
            encoding: .utf8
        )
        let baseline = SemanticPublicAPIBaseline()

        let originalReport = try baseline.render(symbolGraphs: [original])
        let changedReport = try baseline.render(symbolGraphs: [changed])
        let relocatedReport = try baseline.render(symbolGraphs: [relocated])

        #expect(originalReport != changedReport)
        #expect(originalReport == relocatedReport)
        #expect(changedReport.contains("value: String"))
    }

    @Test
    func mergesExtensionGraphsIntoTheirDeclaringModule() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-api-extension-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let primary = root.appendingPathComponent("Fixture.symbols.json")
        let companion = root.appendingPathComponent("Fixture@Other.symbols.json")
        try semanticSymbolGraph(function: "primary", moduleName: "Fixture").write(
            to: primary,
            atomically: true,
            encoding: .utf8
        )
        try semanticSymbolGraph(function: "extensionEntryPoint", moduleName: "Fixture").write(
            to: companion,
            atomically: true,
            encoding: .utf8
        )

        let report = try SemanticPublicAPIBaseline().render(symbolGraphs: [primary, companion])

        #expect(report.components(separatedBy: "## `Fixture`").count == 2)
        #expect(report.contains("primary()"))
        #expect(report.contains("extensionEntryPoint()"))
    }

    @Test
    func capturesSemanticSignatureDetails() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-api-signature-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let baseline = SemanticPublicAPIBaseline()
        let original = root.appendingPathComponent("original.symbols.json")
        let originalDeclaration =
            "@MainActor func update<T>(_ value: borrowing T = default) "
            + "async throws(Failure) -> T where T: Sendable"
        let commonDetails = semanticDetails(conformance: "Sendable", introduced: 14)
        try semanticSymbolGraph(
            declaration: originalDeclaration,
            details: commonDetails
        ).write(to: original, atomically: true, encoding: .utf8)
        let originalReport = try baseline.render(symbolGraphs: [original])

        let declarationChanges = [
            originalDeclaration.replacingOccurrences(of: "borrowing", with: "consuming"),
            originalDeclaration.replacingOccurrences(of: "@MainActor ", with: ""),
            originalDeclaration.replacingOccurrences(of: " = default", with: ""),
            originalDeclaration.replacingOccurrences(of: "Failure", with: "OtherFailure"),
        ]
        for (index, declaration) in declarationChanges.enumerated() {
            let changed = root.appendingPathComponent("changed-\(index).symbols.json")
            try semanticSymbolGraph(declaration: declaration, details: commonDetails).write(
                to: changed,
                atomically: true,
                encoding: .utf8
            )
            #expect(try baseline.render(symbolGraphs: [changed]) != originalReport)
        }

        let detailChanges = [
            semanticDetails(conformance: "Copyable", introduced: 14),
            semanticDetails(conformance: "Sendable", introduced: 15),
        ]
        for (index, details) in detailChanges.enumerated() {
            let changed = root.appendingPathComponent("details-\(index).symbols.json")
            try semanticSymbolGraph(declaration: originalDeclaration, details: details).write(
                to: changed,
                atomically: true,
                encoding: .utf8
            )
            #expect(try baseline.render(symbolGraphs: [changed]) != originalReport)
        }
    }

    @Test
    func ignoresDocComments() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-api-doc-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = root.appendingPathComponent("original.symbols.json")
        let documented = root.appendingPathComponent("documented.symbols.json")
        try semanticSymbolGraph(declaration: "func update(value: Int)").write(
            to: original,
            atomically: true,
            encoding: .utf8
        )
        try semanticSymbolGraph(
            declaration: "func update(value: Int)",
            docComment: "Explains the public behavior without changing the signature."
        ).write(to: documented, atomically: true, encoding: .utf8)

        let baseline = SemanticPublicAPIBaseline()
        #expect(
            try baseline.render(symbolGraphs: [original])
                == baseline.render(symbolGraphs: [documented])
        )
    }

    private func semanticSymbolGraph(parameterType: String, line: Int) -> String {
        """
        {
          "module": { "name": "Fixture" },
          "symbols": [
            {
              "kind": { "identifier": "swift.func" },
              "identifier": {
                "precise": "s:7Fixture6update5valuey\(parameterType == "Int" ? "Si" : "SS")_tF"
              },
              "pathComponents": ["update(value:)"],
              "declarationFragments": [
                { "spelling": "func update(\\n" },
                { "spelling": "value: \(parameterType)\\n" },
                { "spelling": ")" }
              ],
              "accessLevel": "public",
              "location": {
                "uri": "file:///tmp/Fixture.swift",
                "position": { "line": \(line), "character": 0 }
              }
            }
          ],
          "relationships": []
        }
        """
    }

    private func semanticSymbolGraph(function: String, moduleName: String) -> String {
        """
        {
          "module": { "name": "\(moduleName)" },
          "symbols": [
            {
              "kind": { "identifier": "swift.func" },
              "identifier": { "precise": "s:\(moduleName).\(function)" },
              "pathComponents": ["\(function)()"],
              "declarationFragments": [
                { "spelling": "func \(function)()" }
              ],
              "accessLevel": "public"
            }
          ],
          "relationships": []
        }
        """
    }

    private func semanticSymbolGraph(
        declaration: String,
        details: [String: Any] = [:],
        docComment: String? = nil
    ) throws -> String {
        var symbol: [String: Any] = [
            "kind": ["identifier": "swift.func"],
            "identifier": ["precise": "s:7Fixture6update5valueyxxlF"],
            "pathComponents": ["update(value:)"],
            "declarationFragments": [["spelling": declaration]],
            "accessLevel": "public",
            "location": [
                "uri": "file:///tmp/Fixture.swift",
                "position": ["line": 10, "character": 0],
            ],
        ]
        for (key, value) in details {
            symbol[key] = value
        }
        if let docComment {
            symbol["docComment"] = ["lines": [["text": docComment]]]
        }
        let root: [String: Any] = [
            "module": ["name": "Fixture"],
            "symbols": [symbol],
            "relationships": [],
        ]
        let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        return try #require(String(bytes: data, encoding: .utf8))
    }

    private func semanticDetails(conformance: String, introduced: Int) -> [String: Any] {
        [
            "availability": [["domain": "macOS", "introduced": ["major": introduced]]],
            "swiftGenerics": [
                "constraints": [
                    ["kind": "conformance", "lhs": "T", "rhs": conformance]
                ]
            ],
        ]
    }
}
