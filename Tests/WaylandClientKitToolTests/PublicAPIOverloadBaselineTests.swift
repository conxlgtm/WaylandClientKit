import Foundation
import Testing

@testable import WaylandClientKitToolSupport

@Suite
struct PublicAPIOverloadBaselineTests {
    @Test
    func preservesCompleteSignaturesForOverloadedConsumingMethods() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-api-overload-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let graph = root.appendingPathComponent("Fixture.symbols.json")
        let declarations = [
            (
                precise: "s:7Fixture5LeaseV6submityySiF",
                path: "Lease.submit(_:)",
                declaration: "consuming func submit(_ value: Int)"
            ),
            (
                precise: "s:7Fixture5LeaseV6submityySSF",
                path: "Lease.submit(_:)",
                declaration: "consuming func submit(_ value: String)"
            ),
        ]
        let symbols: [[String: Any]] = declarations.map { declaration in
            [
                "kind": ["identifier": "swift.method"],
                "identifier": ["precise": declaration.precise],
                "pathComponents": [declaration.path],
                "declarationFragments": [["spelling": declaration.declaration]],
                "accessLevel": "public",
            ]
        }
        let graphData = try JSONSerialization.data(
            withJSONObject: [
                "module": ["name": "Fixture"],
                "symbols": symbols,
                "relationships": [],
            ],
            options: [.sortedKeys]
        )
        try graphData.write(to: graph)

        let report = try SemanticPublicAPIBaseline().render(symbolGraphs: [graph])

        for declaration in declarations {
            #expect(report.contains(declaration.path))
            #expect(report.contains(declaration.declaration))
        }
    }
}
