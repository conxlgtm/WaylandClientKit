import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct DocumentationStructureVerifierTests {
    @Test
    func requiresProtocolCorrectTextInputDisableLanguage() throws {
        let root = try temporaryRepository()
        defer { Self.removeTemporaryRepository(root) }
        let requiredPhrase = "sends the protocol disable request followed by"
        try writeRequiredDocumentation(root: root, omittedPhrase: requiredPhrase)

        do {
            try DocumentationStructureVerifier(repository: Repository(root: root)).verify()
            Issue.record("expected documentation coverage to require text-input disable details")
        } catch let error as ToolError {
            #expect(error.message.contains("TextInputLifecycle.md"))
            #expect(error.message.contains(requiredPhrase))
        }
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "wayland-client-kit-documentation-verifier-tests-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func removeTemporaryRepository(_ root: URL) {
        do {
            try FileManager.default.removeItem(at: root)
        } catch {
            // Temporary test directory removal is best effort.
        }
    }

    private func writeRequiredDocumentation(root: URL, omittedPhrase: String) throws {
        let phraseMap = Dictionary(
            grouping: DocumentationStructureVerifier.requiredPhrases,
            by: \.path)
        for path in DocumentationStructureVerifier.requiredFiles {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let phrases = phraseMap[path, default: []]
                .map(\.phrase)
                .filter { $0 != omittedPhrase }
                .joined(separator: "\n")
            try "# Test\n\(phrases)\n".write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
