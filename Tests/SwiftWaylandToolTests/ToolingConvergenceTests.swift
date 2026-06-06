import Foundation
import SwiftWaylandToolSupport
import Testing

@Suite
struct ToolingConvergenceTests {
    @Test
    func dependencyBoundaryAcceptsToolOnlyArgumentParser() throws {
        let dump = packageDump(
            targets: """
                    {
                      "name": "WaylandClient",
                      "dependencies": [
                        { "byName": ["WaylandRaw", null] }
                      ]
                    },
                    {
                      "name": "WaylandRaw",
                      "dependencies": []
                    },
                    {
                      "name": "WaylandGraphicsPreview",
                      "dependencies": [
                        { "byName": ["WaylandClient", null] }
                      ]
                    },
                    {
                      "name": "SwiftWaylandTool",
                      "dependencies": [
                        { "product": ["ArgumentParser", "swift-argument-parser", null, null] }
                      ]
                    }
                """)

        try PackageDependencyBoundaryVerifier().verify(packageDump: dump)
    }

    @Test
    func dependencyBoundaryRejectsArgumentParserInPublicProductGraph() throws {
        let dump = packageDump(
            targets: """
                    {
                      "name": "WaylandClient",
                      "dependencies": [
                        { "product": ["ArgumentParser", "swift-argument-parser", null, null] }
                      ]
                    },
                    {
                      "name": "WaylandGraphicsPreview",
                      "dependencies": [
                        { "byName": ["WaylandClient", null] }
                      ]
                    }
                """)

        do {
            try PackageDependencyBoundaryVerifier().verify(packageDump: dump)
            Issue.record("expected public dependency graph leak to fail")
        } catch let error as ToolError {
            #expect(error.message.contains("WaylandClient dependency graph includes"))
            #expect(error.message.contains("ArgumentParser"))
        }
    }

    @Test
    func compositorEvidenceSummaryCountsPendingRows() throws {
        let graphicsHeader = [
            "Compositor", "Display", "Globals", "dmabuf", "surface feedback", "GBM", "EGL",
            "explicit sync", "FIFO", "commit timing", "metadata", "presentation feedback",
            "submitted frame", "release/reuse", "backing", "failure/fallback",
        ].joined(separator: " | ")
        let graphicsSeparator = Array(repeating: "----------", count: 16).joined(separator: " | ")
        let graphicsRow = [
            "GNOME / Mutter", "wayland-0", "dmabuf", "advertised", "fallback", "fallback",
            "fallback", "advertised", "advertised", "advertised", "pending", "advertised",
            "success", "not observed", "software fallback", "none",
        ].joined(separator: " | ")
        let markdown = """
            # Compositor Matrix

            ## Matrix

            | Compositor | Version | Protocol facts | Smoke |
            | ---------- | ------- | -------------- | ----- |
            | Weston headless | pending | pending | pass |
            | GNOME / Mutter | 46 | facts recorded | pass |

            ## Graphics Preview Evidence

            | \(graphicsHeader) |
            | \(graphicsSeparator) |
            | \(graphicsRow) |
            """

        let summary = try CompositorEvidenceSummarizer().summarize(markdown: markdown)

        #expect(summary.contains("Weston headless: 1 recorded, 2 pending"))
        #expect(summary.contains("GNOME / Mutter: submitted frame=success"))
    }

    @Test
    func toolchainSmokeReadsPackageToolsVersion() throws {
        let root = try temporaryRepository()
        try """
        // swift-tools-version: 6.3.2
        import PackageDescription
        """.write(
            to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let version = try ToolchainSmoke.packageToolsVersion(
            repository: Repository(root: root),
            fileSystem: LocalFileSystem())

        #expect(version == "6.3.2")
    }

    @Test
    func toolchainSmokeClassifiesSwiftBuildPreviewResults() {
        let unsupported = ProcessResult(
            executable: "swift",
            arguments: [],
            exitCode: 64,
            stdout: "",
            stderr: "error: unknown option '--build-system'")
        let packageFailure = ProcessResult(
            executable: "swift",
            arguments: [],
            exitCode: 1,
            stdout: "",
            stderr: "error: failed to build package")

        #expect(ToolchainSmoke.classifySwiftBuildPreview(result: unsupported) == "unsupported")
        #expect(
            ToolchainSmoke.classifySwiftBuildPreview(result: packageFailure)
                == "failed-package(exit 1)")
    }

    @Test
    func exampleBuilderTracksEveryExampleExecutable() {
        #expect(ExampleBuilder.targets.contains("CustomCursorSmoke"))
        #expect(ExampleBuilder.targets.contains("SubsurfaceSmoke"))
        #expect(ExampleBuilder.targets.contains("SwiftWaylandDemo"))
        #expect(ExampleBuilder.targets.count == 21)
    }

    private func packageDump(targets: String) -> String {
        """
        {
          "targets": [
        \(targets)
          ]
        }
        """
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftwayland-tooling-convergence-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
