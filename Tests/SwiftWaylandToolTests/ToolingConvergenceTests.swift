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
            | KDE / KWin | 6 | manual interaction required(pointer capture) | pass |
            | Sway / wlroots | environment skip(sway) | environment skip(sway) | pass |

            ## Framework Host Evidence

            | Compositor | Pointer capture |
            | ---------- | --------------- |
            | KDE / KWin | manual interaction required(lock/confine motion) |

            ## Graphics Preview Evidence

            | \(graphicsHeader) |
            | \(graphicsSeparator) |
            | \(graphicsRow) |
            """

        let summary = try CompositorEvidenceSummarizer().summarize(markdown: markdown)

        #expect(summary.contains("Weston headless: 1 recorded, 2 pending"))
        #expect(summary.contains("KDE / KWin: 2 recorded, 1 manual interaction gap"))
        #expect(summary.contains("Sway / wlroots: 1 recorded, 2 environment skips"))
        #expect(summary.contains("GNOME / Mutter: submitted frame=success"))
        #expect(summary.contains("3 pending, 2 environment skips, 2 manual interaction gaps"))
        #expect(summary.contains("## Framework Host Evidence: KDE / KWin / Pointer capture"))
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
    func documentationCoverageReportsMissingRequiredArticle() throws {
        let root = try temporaryRepository()
        try writeRequiredDocumentation(root: root, missing: "docs/getting-started.md")

        do {
            try DocumentationCoverageVerifier(repository: Repository(root: root)).verify()
            Issue.record("expected documentation coverage to fail")
        } catch let error as ToolError {
            #expect(
                error.message.contains(
                    "Missing required documentation file: docs/getting-started.md"))
        }
    }

    @Test
    func documentationCoverageRequiresKeyPortalAndPreviewLanguage() throws {
        let root = try temporaryRepository()
        try writeRequiredDocumentation(
            root: root,
            omittedPhrase: "docs/which-api-should-i-use.md")

        do {
            try DocumentationCoverageVerifier(repository: Repository(root: root)).verify()
            Issue.record("expected documentation coverage to require README API chooser link")
        } catch let error as ToolError {
            #expect(error.message.contains("README.md"))
            #expect(error.message.contains("docs/which-api-should-i-use.md"))
        }
    }

    @Test
    func exampleBuilderTracksEveryExampleExecutable() {
        #expect(ExampleBuilder.targets.contains("CustomCursorSmoke"))
        #expect(ExampleBuilder.targets.contains("SessionStateSmoke"))
        #expect(ExampleBuilder.targets.contains("SubsurfaceSmoke"))
        #expect(ExampleBuilder.targets.contains("SwiftWaylandDemo"))
        #expect(ExampleBuilder.targets.count == 22)
    }

    @Test
    func integrationPackageTestsDisableIndexStore() throws {
        let source = try String(
            contentsOf: repositoryRoot()
                .appendingPathComponent("Sources/SwiftWaylandTool/main.swift"),
            encoding: .utf8)
        let start = try #require(source.range(of: "private func runIntegrationPackage"))
        let end = try #require(source.range(of: "private func compilerFilterEnvironment"))
        let functionBody = String(source[start.lowerBound..<end.lowerBound])

        #expect(functionBody.contains("\"--disable-index-store\""))
        #expect(functionBody.contains("prepareIntegrationIndexStoreDirectory"))
        #expect(functionBody.contains("\"-print-target-info\""))
        #expect(functionBody.contains(".appendingPathComponent(\"index\")"))
        #expect(functionBody.contains(".appendingPathComponent(\"store\")"))
    }

    @Test
    func exampleBuilderDiscoversExampleTargetsFromPackageManifest() throws {
        let root = try temporaryRepository()
        try """
        // swift-tools-version: 6.3.2
        import PackageDescription
        let package = Package(
            name: "Probe",
            targets: [
                .executableTarget(
                    name: "NamedSmoke",
                    dependencies: [],
                    path: "Examples/CustomPath"
                ),
                .executableTarget(
                    dependencies: [],
                    path: "Examples/PathNamedSmoke"
                ),
                .executableTarget(
                    name: "NotAnExample",
                    path: "Sources/NotAnExample"
                ),
            ]
        )
        """.write(
            to: root.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8)

        let targets = try ExampleBuilder.packageExampleTargets(repository: Repository(root: root))

        #expect(targets == ["NamedSmoke", "PathNamedSmoke"])
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

    private func repositoryRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 {
            url.deleteLastPathComponent()
        }
        return url
    }

    private func writeRequiredDocumentation(
        root: URL,
        missing missingPath: String? = nil,
        omittedPhrase: String? = nil
    ) throws {
        let phraseMap = Dictionary(
            grouping: DocumentationCoverageVerifier.requiredPhrases,
            by: \.path)
        for path in DocumentationCoverageVerifier.requiredFiles where path != missingPath {
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
