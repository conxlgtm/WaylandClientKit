import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct PublicIdentityAuditorTests {
    @Test
    func generatesAndVerifiesIdentityVisibility() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-identity-audit-\(UUID().uuidString)")
        let source = root.appendingPathComponent(
            "Sources/WaylandClient/Public/FixtureID.swift"
        )
        let previewSource = root.appendingPathComponent(
            "Sources/WaylandGraphicsPreviewAPI/Public/PreviewFixtureID.swift"
        )
        let manifest = root.appendingPathComponent("docs/identity-categories.json")
        try FileManager.default.createDirectory(
            at: source.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: previewSource.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: manifest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fixtureSource(constructor: "package").write(
            to: source,
            atomically: true,
            encoding: .utf8
        )
        try previewFixtureSource.write(to: previewSource, atomically: true, encoding: .utf8)
        try fixtureManifest.write(to: manifest, atomically: true, encoding: .utf8)
        let auditor = PublicIdentityAuditor(repository: Repository(root: root))

        try auditor.verify(update: true)
        try auditor.verify(update: false)
        let report = try String(
            contentsOf: root.appendingPathComponent("docs/identity-visibility.md"),
            encoding: .utf8
        )
        #expect(report.contains("| `FixtureID` | client identity | `package` |"))
        #expect(report.contains("| `PreviewFixtureID` | client identity | `package` |"))

        try fixtureSource(constructor: "public").write(
            to: source,
            atomically: true,
            encoding: .utf8
        )
        #expect(throws: ToolError.self) {
            _ = try auditor.render()
        }
    }

    private var fixtureManifest: String {
        """
        {
          "identities": [
            {
              "type": "FixtureID",
              "category": "client identity",
              "constructor": "package",
              "storage": "rawValue",
              "storageVisibility": "package"
            },
            {
              "type": "PreviewFixtureID",
              "category": "client identity",
              "constructor": "package",
              "storage": "rawValue",
              "storageVisibility": "package"
            }
          ]
        }
        """
    }

    private func fixtureSource(constructor: String) -> String {
        """
        public struct FixtureID {
            package let rawValue: UInt64

            \(constructor) init(rawValue: UInt64) {
                self.rawValue = rawValue
            }
        }
        """
    }

    private var previewFixtureSource: String {
        """
        public struct PreviewFixtureID {
            package let rawValue: UInt64

            package init(rawValue: UInt64) {
                self.rawValue = rawValue
            }
        }
        """
    }
}
