import Foundation
import Testing

@testable import WaylandClientKitToolSupport

struct DocumentationSymbolCoverageTests {
    @Test
    func countsPublicContractSymbolsWithAbstracts() throws {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { Self.removeScratch(scratch) }
        let graph = scratch.appendingPathComponent("Example.symbols.json")
        try Self.graph(documented: true).write(to: graph, atomically: true, encoding: .utf8)

        let coverage = try DocumentationSymbolCoverageVerifier().measure(symbolGraphs: [graph])

        #expect(coverage.products["Example"] == .init(eligible: 2, documented: 1))
    }

    @Test
    func rejectsCoverageRatioRegression() throws {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { Self.removeScratch(scratch) }
        let graph = scratch.appendingPathComponent("Example.symbols.json")
        let baseline = scratch.appendingPathComponent("coverage.json")
        try Self.graph(documented: false).write(to: graph, atomically: true, encoding: .utf8)
        try #"{"products":{"Example":{"documented":1,"eligible":2}}}"#
            .write(to: baseline, atomically: true, encoding: .utf8)

        #expect(throws: ToolError.self) {
            try DocumentationSymbolCoverageVerifier().verify(
                symbolGraphs: [graph], baseline: baseline, update: false)
        }
    }

    @Test
    func excludesDocumentationInheritedFromDependencyModules() throws {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { Self.removeScratch(scratch) }
        let graph = scratch.appendingPathComponent("Example.symbols.json")
        try """
        {"module":{"name":"Example"},"symbols":[
          {"kind":{"identifier":"swift.struct"},"accessLevel":"public",
           "docComment":{"module":"Example","lines":[{"text":"A product value."}]}},
          {"kind":{"identifier":"swift.init"},"accessLevel":"public",
           "docComment":{"module":"Swift","lines":[{"text":"Creates a new raw value."}]}},
          {"kind":{"identifier":"swift.method"},"accessLevel":"public"}
        ]}
        """.write(to: graph, atomically: true, encoding: .utf8)

        let coverage = try DocumentationSymbolCoverageVerifier().measure(symbolGraphs: [graph])
        #expect(coverage.products["Example"] == .init(eligible: 3, documented: 1))
    }

    private static func graph(documented: Bool) -> String {
        let comment =
            documented
            ? #", "docComment":{"lines":[{"text":"A public type."}]}"#
            : ""
        return """
            {"module":{"name":"Example"},"symbols":[
              {"kind":{"identifier":"swift.struct"},"accessLevel":"public"\(comment)},
              {"kind":{"identifier":"swift.method"},"accessLevel":"public"},
              {"kind":{"identifier":"swift.property"},"accessLevel":"public",
               "docComment":{"lines":[{"text":"Excluded property."}]}},
              {"kind":{"identifier":"swift.enum.case"},"accessLevel":"package",
               "docComment":{"lines":[{"text":"Excluded package case."}]}}
            ]}
            """
    }

    private static func removeScratch(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // Temporary test directory removal is best effort.
        }
    }
}
