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

        let output = root.appendingPathComponent(
            "Sources/Fixture/Generated/FixtureIdentities.swift"
        )
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
    func policyRejectsUnknownAuditCategory() throws {
        let policy = fixturePolicy.replacingOccurrences(
            of: "raw protocol identity",
            with: "client identty"
        )
        let root = try fixtureRepository(policy: policy)

        #expect(throws: ToolError.self) {
            _ = try IdentityGenerator(repository: Repository(root: root)).render()
        }
    }

    @Test
    func clientIdentityCannotExposePublicStorage() throws {
        let policy = fixturePolicy.replacingOccurrences(
            of: "raw protocol identity",
            with: "client identity"
        )
        let root = try fixtureRepository(policy: policy)

        #expect(throws: ToolError.self) {
            _ = try IdentityGenerator(repository: Repository(root: root)).render()
        }
    }

    @Test
    func projectionIdentityCannotExposePublicConstruction() throws {
        let policy =
            fixturePolicy
            .replacingOccurrences(of: "raw protocol identity", with: "public projection")
            .replacingOccurrences(
                of: "\"storageAccess\": \"public\"", with: "\"storageAccess\": \"package\"")
        let root = try fixtureRepository(policy: policy)

        #expect(throws: ToolError.self) {
            _ = try IdentityGenerator(repository: Repository(root: root)).render()
        }
    }

    @Test
    func rawProtocolIdentityCanExposeItsProtocolValue() throws {
        let root = try fixtureRepository()
        let files = try IdentityGenerator(repository: Repository(root: root)).render()
        let swift = try #require(firstSwiftFile(in: files))

        #expect(swift.contents.contains("public let rawValue: UInt64"))
        #expect(swift.contents.contains("public init(rawValue fixtureRawValue: UInt64)"))
    }

    @Test
    func generationRefusesToReplaceHandwrittenFile() throws {
        let root = try fixtureRepository()
        let output = root.appendingPathComponent(
            "Sources/Fixture/Generated/FixtureIdentities.swift"
        )
        let handwritten = "struct HandwrittenValue {}\n"
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try handwritten.write(to: output, atomically: true, encoding: .utf8)

        #expect(throws: ToolError.self) {
            try IdentityGenerator(repository: Repository(root: root)).generate()
        }
        #expect(try String(contentsOf: output, encoding: .utf8) == handwritten)
    }

    @Test
    func policyRejectsOutputOutsideGeneratedDirectory() throws {
        let policy = fixturePolicy.replacingOccurrences(
            of: "Sources/Fixture/Generated/FixtureIdentities.swift",
            with: "Sources/Fixture/FixtureIdentities.swift"
        )
        let root = try fixtureRepository(policy: policy)

        #expect(throws: ToolError.self) {
            _ = try IdentityGenerator(repository: Repository(root: root)).render()
        }
    }

    @Test
    func generationPreflightsEveryDestinationBeforeWriting() throws {
        let root = try fixtureRepository(policy: twoOutputFixturePolicy)
        let generator = IdentityGenerator(repository: Repository(root: root))
        try generator.generate()

        let first = root.appendingPathComponent(
            "Sources/Fixture/Generated/FixtureIdentities.swift"
        )
        let second = root.appendingPathComponent(
            "Sources/Fixture/Generated/OtherIdentities.swift"
        )
        let firstBefore = try String(contentsOf: first, encoding: .utf8)
        let handwritten = "struct HandwrittenValue {}\n"
        try handwritten.write(to: second, atomically: true, encoding: .utf8)
        try writePolicy(
            twoOutputFixturePolicy.replacingOccurrences(of: "fixture-", with: "changed-"),
            to: root
        )

        #expect(throws: ToolError.self) {
            try generator.generate()
        }
        #expect(try String(contentsOf: first, encoding: .utf8) == firstBefore)
        #expect(try String(contentsOf: second, encoding: .utf8) == handwritten)
    }

    @Test
    func generationReportsAndRemovesOwnedOrphans() throws {
        let root = try fixtureRepository(policy: twoOutputFixturePolicy)
        let generator = IdentityGenerator(repository: Repository(root: root))
        try generator.generate()

        let orphan = root.appendingPathComponent(
            "Sources/Fixture/Generated/OtherIdentities.swift"
        )
        let handwritten = root.appendingPathComponent(
            "Sources/Fixture/Generated/Handwritten.swift"
        )
        try "struct HandwrittenValue {}\n".write(
            to: handwritten,
            atomically: true,
            encoding: .utf8
        )
        try writePolicy(fixturePolicy, to: root)

        do {
            try generator.verifyGenerated()
            Issue.record("Expected verification to report the orphaned generated file")
        } catch let error as ToolError {
            #expect(error.message.contains("unexpected generated file"))
            #expect(error.message.contains("OtherIdentities.swift"))
        }

        try generator.generate()
        #expect(!FileManager.default.fileExists(atPath: orphan.path))
        #expect(FileManager.default.fileExists(atPath: handwritten.path))
        try generator.verifyGenerated()
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
}

extension IdentityGenerationTests {
    private func isPublicDeclaration(_ line: String) -> Bool {
        let source = line.trimmingCharacters(in: .whitespaces)
        return source.hasPrefix("public struct ")
            || source.hasPrefix("public let ")
            || source.hasPrefix("public init(")
            || source.hasPrefix("public typealias ")
            || source.hasPrefix("public var ")
    }

    private func firstSwiftFile(in files: [GeneratedIdentityFile]) -> GeneratedIdentityFile? {
        files.first { $0.path.hasSuffix(".swift") }
    }

    private func fixtureRepository(
        manualType: String = "ManualToken",
        policy: String? = nil
    ) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-identity-generation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("identities"),
            withIntermediateDirectories: true
        )
        try (policy ?? fixturePolicy).write(
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
              "path": "Sources/Fixture/Generated/FixtureIdentities.swift",
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
              "auditCategory": "raw protocol identity",
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

    private var twoOutputFixturePolicy: String {
        """
        {
          "outputs": [
            {
              "id": "fixture",
              "path": "Sources/Fixture/Generated/FixtureIdentities.swift",
              "imports": []
            },
            {
              "id": "other",
              "path": "Sources/Fixture/Generated/OtherIdentities.swift",
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
              "conformances": ["Hashable", "Sendable"],
              "description": { "prefix": "fixture-" },
              "auditCategory": "raw protocol identity",
              "documentation": {
                "summary": "Identifies one generated fixture.",
                "storage": "The numeric fixture identity.",
                "constructor": "Creates a fixture identity from its numeric value.",
                "description": "A stable diagnostic description of the fixture."
              }
            },
            {
              "type": "OtherID",
              "output": "other",
              "access": "public",
              "rawType": "UInt64",
              "storageAccess": "public",
              "constructorAccess": "public",
              "constructorParameter": "otherRawValue",
              "conformances": ["Hashable", "Sendable"],
              "auditCategory": "raw protocol identity",
              "documentation": {
                "summary": "Identifies another generated fixture.",
                "storage": "The numeric fixture identity.",
                "constructor": "Creates another fixture identity from its numeric value."
              }
            }
          ]
        }
        """
    }

    private func writePolicy(_ policy: String, to root: URL) throws {
        try policy.write(
            to: root.appendingPathComponent(IdentityGenerator.policyPath),
            atomically: true,
            encoding: .utf8
        )
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
