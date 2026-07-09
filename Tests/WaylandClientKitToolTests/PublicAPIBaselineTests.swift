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
}
