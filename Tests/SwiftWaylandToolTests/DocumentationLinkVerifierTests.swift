import Foundation
import SwiftWaylandToolSupport
import Testing

@Suite
struct DocumentationLinkVerifierTests {
    @Test
    func acceptsValidLocalLinks() throws {
        let root = try temporaryRepository()
        let docs = root.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let readme = root.appendingPathComponent("README.md")
        let guide = docs.appendingPathComponent("guide.md")
        try """
        # SwiftWayland

        Read the [guide](docs/guide.md#setup).
        """.write(to: readme, atomically: true, encoding: .utf8)
        try """
        # Guide

        ## Setup
        """.write(to: guide, atomically: true, encoding: .utf8)

        try DocumentationLinkVerifier(repository: Repository(root: root)).verify(
            files: [readme, guide])
    }

    @Test
    func rejectsBrokenLocalLinks() throws {
        let root = try temporaryRepository()
        let readme = root.appendingPathComponent("README.md")
        try """
        # SwiftWayland

        See [missing docs](docs/missing.md).
        """.write(to: readme, atomically: true, encoding: .utf8)

        do {
            try DocumentationLinkVerifier(repository: Repository(root: root)).verify(
                files: [readme])
            Issue.record("expected documentation link verification to reject broken links")
        } catch let error as ToolError {
            #expect(error.message.contains("broken local Markdown link"))
            #expect(error.message.contains("README.md:3"))
        }
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftwayland-doc-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "".write(
            to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("protocols"), withIntermediateDirectories: true)
        return root
    }
}
