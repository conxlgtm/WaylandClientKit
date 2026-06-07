import Foundation
import SwiftWaylandToolSupport
import Testing

@Suite
struct DocCVerifierProductTests {
    @Test
    func doccVerifierRequiresPreviewCatalog() throws {
        let root = try temporaryRepository()
        try createDocCCatalog(
            root: root,
            catalogPath: "Sources/WaylandClient/WaylandClient.docc",
            articleName: "WaylandClient.md"
        )

        let verifier = DocCVerifier(repository: Repository(root: root))
        do {
            try verifier.verifyCatalogExists()
            Issue.record("expected DocC verifier to require preview catalog")
        } catch let error as ToolError {
            #expect(error.message.contains("WaylandGraphicsPreview"))
            #expect(
                error.message.contains(
                    "Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc"
                )
            )
        }
    }

    @Test
    func doccVerifierRequiresEveryPublicProductSymbolGraph() throws {
        let root = try temporaryRepository()
        let scratch = root.appendingPathComponent(".scratch")
        let clientGraph = scratch.appendingPathComponent(
            "debug/symbolgraph/WaylandClient.symbols.json")
        try FileManager.default.createDirectory(
            at: clientGraph.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try #"{"symbols":[]}"#.write(to: clientGraph, atomically: true, encoding: .utf8)

        let result = ProcessResult(
            executable: "swift",
            arguments: ["package", "dump-symbol-graph"],
            exitCode: 0,
            stdout: "",
            stderr: "")
        let verifier = DocCVerifier(repository: Repository(root: root), buildRoot: scratch)

        do {
            try verifier.requirePublicProductSymbolGraphs(afterDump: result)
            Issue.record("expected DocC verifier to require preview symbol graph")
        } catch let error as ToolError {
            #expect(error.message.contains("Missing WaylandGraphicsPreview symbol graph"))
        }
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftwayland-docc-product-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "".write(
            to: root.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Sources"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Tests"),
            withIntermediateDirectories: true
        )
        return root
    }

    private func createDocCCatalog(root: URL, catalogPath: String, articleName: String) throws {
        let catalog = root.appendingPathComponent(catalogPath)
        try FileManager.default.createDirectory(at: catalog, withIntermediateDirectories: true)
        try "# Test\n".write(
            to: catalog.appendingPathComponent(articleName),
            atomically: true,
            encoding: .utf8
        )
    }
}
