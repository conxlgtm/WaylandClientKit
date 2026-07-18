import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct IdentityGenerationTests {
    @Test
    func rendererIsDeterministicAndEmitsConcreteTypes() throws {
        let root = try fixtureRepository()
        let generator = IdentityGenerator(repository: Repository(root: root))

        let first = try generator.render()
        let second = try generator.render()

        #expect(first == second)
        let swift = try #require(first.first { $0.path.hasSuffix("FixtureIdentities.swift") })
        #expect(swift.contents.contains("public struct FixtureID"))
        #expect(swift.contents.contains("/// Identifies one generated fixture."))
        #expect(swift.contents.contains("extension FixtureID: UInt64WaylandEntityID"))
    }

    @Test
    func verificationRejectsStaleCheckedInOutput() throws {
        let root = try fixtureRepository()
        let generator = IdentityGenerator(repository: Repository(root: root))
        try generator.generate()
        try generator.verifyGenerated()

        let output = root.appendingPathComponent("Sources/Fixture/FixtureIdentities.swift")
        try "stale\n".write(to: output, atomically: true, encoding: .utf8)

        #expect(throws: ToolError.self) {
            try generator.verifyGenerated()
        }
    }

    @Test
    func auditManifestCombinesDerivedAndManualEntries() throws {
        let root = try fixtureRepository()
        let files = try IdentityGenerator(repository: Repository(root: root)).render()
        let audit = try #require(
            files.first { $0.path == IdentityGenerator.auditOutputPath }
        )
        let data = try #require(audit.contents.data(using: .utf8))
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: [[String: String]]]
        )
        let identities = try #require(object["identities"])

        #expect(identities.map { $0["type"] } == ["FixtureID", "ManualToken"])
        #expect(identities[0]["constructor"] == "public")
        #expect(identities[0]["storage"] == "rawValue")
        #expect(identities[0]["storageVisibility"] == "public")
        #expect(identities[1]["category"] == "opaque protocol token")
    }

    @Test
    func auditManifestRejectsGeneratedAndManualOverlap() throws {
        let root = try fixtureRepository(manualType: "FixtureID")
        let generator = IdentityGenerator(repository: Repository(root: root))

        #expect(throws: ToolError.self) {
            _ = try generator.render()
        }
    }

    @Test
    func checkedInPublicGeneratedAPIIsDocumented() throws {
        let repository = Repository(root: try repositoryRoot())
        let files = try IdentityGenerator(repository: repository).render()
        let publicFiles = files.filter { file in
            file.path.contains("/Public/Generated/") && file.path.hasSuffix(".swift")
        }
        #expect(publicFiles.count == 2)

        for file in publicFiles {
            let lines = file.contents.split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() where isPublicDeclaration(String(line)) {
                var precedingIndex = index - 1
                while precedingIndex >= 0,
                    lines[precedingIndex].trimmingCharacters(in: .whitespaces).hasPrefix("@")
                {
                    precedingIndex -= 1
                }
                #expect(
                    precedingIndex >= 0
                        && lines[precedingIndex]
                            .trimmingCharacters(in: .whitespaces)
                            .hasPrefix("///"),
                    "\(file.path): undocumented declaration `\(line)`"
                )
            }
        }
    }

    private func isPublicDeclaration(_ line: String) -> Bool {
        let source = line.trimmingCharacters(in: .whitespaces)
        return source.hasPrefix("public struct ")
            || source.hasPrefix("public let ")
            || source.hasPrefix("public init(")
            || source.hasPrefix("public typealias ")
            || source.hasPrefix("public var ")
    }

    private func fixtureRepository(manualType: String = "ManualToken") throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-identity-generation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("identities"),
            withIntermediateDirectories: true
        )
        try fixturePolicy.write(
            to: root.appendingPathComponent(IdentityGenerator.policyPath),
            atomically: true,
            encoding: .utf8
        )
        try manualAudit(type: manualType).write(
            to: root.appendingPathComponent(IdentityGenerator.manualAuditPath),
            atomically: true,
            encoding: .utf8
        )
        return root
    }

    private var fixturePolicy: String {
        """
        {
          "outputs": [
            {
              "id": "fixture",
              "path": "Sources/Fixture/FixtureIdentities.swift",
              "imports": []
            }
          ],
          "identities": [
            {
              "type": "FixtureID",
              "output": "fixture",
              "access": "public",
              "rawType": "UInt64",
              "storageAccess": "public",
              "constructorAccess": "public",
              "constructorParameter": "fixtureRawValue",
              "conformances": ["Hashable", "Sendable", "CustomStringConvertible"],
              "sharedIDConformance": "UInt64WaylandEntityID",
              "sharedIDInExtension": true,
              "description": { "prefix": "fixture-" },
              "auditCategory": "client identity",
              "documentation": {
                "summary": "Identifies one generated fixture.",
                "storage": "The numeric fixture identity.",
                "constructor": "Creates a fixture identity from its numeric value.",
                "description": "A stable diagnostic description of the fixture."
              }
            }
          ]
        }
        """
    }

    private func manualAudit(type: String) -> String {
        """
        {
          "identities": [
            {
              "type": "\(type)",
              "category": "opaque protocol token",
              "constructor": "public",
              "storage": "value",
              "storageVisibility": "public"
            }
          ]
        }
        """
    }

    private func repositoryRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while candidate.path != candidate.deletingLastPathComponent().path {
            if FileManager.default.fileExists(
                atPath: candidate.appendingPathComponent(IdentityGenerator.policyPath).path
            ) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        throw ToolError("could not find repository root for identity generation tests")
    }
}
