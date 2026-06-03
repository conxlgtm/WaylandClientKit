import Foundation
import SwiftWaylandToolSupport
import Testing

@Suite
struct ToolSupportTests {
    @Test
    func repositoryRootDetectionUsesEnvironmentOverride() throws {
        let root = try temporaryRepository()
        let detected = try Repository.detect(
            from: root.appendingPathComponent("Sources"),
            environment: ["SWIFT_WAYLAND_ROOT": root.path]
        )
        #expect(detected.root.path == root.path)
    }

    @Test
    func coverageSummaryAggregatesSourceModules() throws {
        let root = try temporaryRepository()
        let source = root.appendingPathComponent("Sources/WaylandClient/File.swift")
        try FileManager.default.createDirectory(
            at: source.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "public struct Sample {}".write(to: source, atomically: true, encoding: .utf8)
        let coverage = root.appendingPathComponent(".build/debug/codecov/SwiftWayland.json")
        try FileManager.default.createDirectory(
            at: coverage.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        {
          "data": [
            {
              "files": [
                {
                  "filename": "\(source.path)",
                  "summary": {
                    "lines": { "count": 10, "covered": 8 },
                    "functions": { "count": 4, "covered": 2 }
                  }
                }
              ]
            }
          ]
        }
        """.write(to: coverage, atomically: true, encoding: .utf8)

        let summary = try CoverageSummarizer(repository: Repository(root: root)).summarize(explicitPath: nil)
        #expect(summary.contains("| `WaylandClient` | 80.00% | 50.00% |"))
    }

    @Test
    func protocolManifestValidationRejectsDuplicateNames() throws {
        let root = try temporaryRepository()
        let manifest = root.appendingPathComponent("protocols/manifest.json")
        let xml = root.appendingPathComponent("protocols/upstream/core/wayland.xml")
        try FileManager.default.createDirectory(
            at: xml.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "<protocol name=\"wayland\"/>".write(to: xml, atomically: true, encoding: .utf8)
        try """
        {
          "protocols": [
            {
              "name": "wayland-core",
              "localPath": "protocols/upstream/core/wayland.xml",
              "upstreamProject": "wayland",
              "upstreamVersion": "1",
              "vendoredFromPackage": "pkg",
              "vendoredFromPath": "/tmp/wayland.xml",
              "sha256": "abc",
              "swiftWaylandTier": "required",
              "apiExposure": "internal",
              "testStrategy": "unit-and-live",
              "notes": "test"
            },
            {
              "name": "wayland-core",
              "localPath": "protocols/upstream/core/wayland.xml",
              "upstreamProject": "wayland",
              "upstreamVersion": "1",
              "vendoredFromPackage": "pkg",
              "vendoredFromPath": "/tmp/wayland.xml",
              "sha256": "abc",
              "swiftWaylandTier": "required",
              "apiExposure": "internal",
              "testStrategy": "unit-and-live",
              "notes": "test"
            }
          ]
        }
        """.write(to: manifest, atomically: true, encoding: .utf8)

        #expect(throws: ToolError.self) {
            try ProtocolTooling(repository: Repository(root: root)).validateManifest()
        }
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftwayland-tool-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "".write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Tests"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Examples"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("protocols"), withIntermediateDirectories: true)
        return root
    }
}

