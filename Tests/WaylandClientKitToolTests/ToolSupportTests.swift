import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct ToolSupportTests {
    @Test
    func repositoryRootDetectionUsesEnvironmentOverride() throws {
        let root = try temporaryRepository()
        let detected = try Repository.detect(
            from: root.appendingPathComponent("Sources"),
            environment: ["WAYLAND_CLIENT_KIT_ROOT": root.path]
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
        let coverage = root.appendingPathComponent(".build/debug/codecov/WaylandClientKit.json")
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

        let summary = try CoverageSummarizer(repository: Repository(root: root)).summarize(
            explicitPath: nil)
        #expect(summary.contains("| `WaylandClient` | 80.00% | 50.00% |"))
    }

    @Test
    func sha256DigestMatchesKnownVector() {
        #expect(
            SHA256Checksum.digest(Array("abc".utf8))
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test
    func swiftToolchainBuildRootUsesConfiguredScratchPath() throws {
        let root = try temporaryRepository()
        let scratch = root.appendingPathComponent(".scratch")
        let toolchain = SwiftToolchain(
            runner: ProcessRunner(
                environment: ["WAYLAND_CLIENT_KIT_SWIFTPM_SCRATCH": scratch.path]))

        #expect(toolchain.swiftPMBuildRoot(repository: Repository(root: root)).path == scratch.path)
    }

    @Test
    func processRunnerRestoresCurrentDirectoryAfterWorkingDirectoryRun() throws {
        let root = try temporaryRepository()
        let originalDirectory = FileManager.default.currentDirectoryPath

        let result = try ProcessRunner().run("/bin/pwd", [], workingDirectory: root)

        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == root.path)
        #expect(FileManager.default.currentDirectoryPath == originalDirectory)
    }

    @Test
    func cCompilerFilterStripsSwiftPMIndexStoreFlags() {
        let arguments = CCompilerFilter.filteredArguments([
            "-DVALUE=1",
            "-index-store-path",
            "/tmp/index-store",
            "-index-unit-output-path=/tmp/unit-output",
            "shim.c",
        ])

        #expect(arguments == ["-DVALUE=1", "shim.c"])
    }

    @Test
    func cCompilerFilterInvokesRealCompilerWithFilteredArguments() throws {
        let truePath = try ProcessRunner().executableURL(for: "true").path

        let result = try CCompilerFilter.run(
            arguments: [
                "-DVALUE=1",
                "-index-store-path",
                "/tmp/index-store",
                "-index-unit-output-path=/tmp/unit-output",
                "shim.c",
            ],
            environment: [
                "PATH": ProcessInfo.processInfo.environment["PATH", default: ""],
                CCompilerFilter.realCompilerEnvironmentKey: truePath,
            ])

        #expect(result.executable == truePath)
        #expect(result.arguments == ["-DVALUE=1", "shim.c"])
    }

    @Test
    func cCompilerFilterEnvironmentSetsCCAndPreservesOverrides() throws {
        let filter = URL(fileURLWithPath: "/tmp/swl")

        let environment = CCompilerFilter.compilerEnvironment(
            filterExecutable: filter,
            base: ["WAYLAND_CLIENT_KIT_ENABLE_PUBLIC_INTEGRATION_TESTS": "1"],
            inherited: ["CC": "/usr/bin/clang"]
        )

        #expect(environment["CC"] == filter.path)
        #expect(environment[CCompilerFilter.modeEnvironmentKey] == "1")
        #expect(environment[CCompilerFilter.realCompilerEnvironmentKey] == "/usr/bin/clang")
        #expect(environment["WAYLAND_CLIENT_KIT_ENABLE_PUBLIC_INTEGRATION_TESTS"] == "1")
    }

    @Test
    func threadSanitizerOptionsIncludeRequiredDefaults() {
        let suppressions = URL(fileURLWithPath: "/tmp/tsan-suppressions.txt")

        let options = SanitizerOptions.threadSanitizerOptions(
            suppressions: suppressions,
            inherited: [:])

        #expect(options == "detect_deadlocks=0:suppressions=/tmp/tsan-suppressions.txt")
    }

    @Test
    func threadSanitizerOptionsPreserveInheritedOptions() {
        let suppressions = URL(fileURLWithPath: "/tmp/tsan-suppressions.txt")

        let options = SanitizerOptions.threadSanitizerOptions(
            suppressions: suppressions,
            inherited: ["TSAN_OPTIONS": "log_path=/tmp/tsan:history_size=7"])

        #expect(
            options
                == "log_path=/tmp/tsan:history_size=7:"
                + "detect_deadlocks=0:suppressions=/tmp/tsan-suppressions.txt")
    }

    @Test
    func doccVerifierUsesConfiguredBuildRootForSymbolGraphs() throws {
        let root = try temporaryRepository()
        let staleBuildGraph = root.appendingPathComponent(
            ".build/debug/symbolgraph/WaylandClient.symbols.json")
        let scratch = root.appendingPathComponent(".scratch")
        let symbolGraph = scratch.appendingPathComponent(
            "debug/symbolgraph/WaylandClient.symbols.json")
        try FileManager.default.createDirectory(
            at: staleBuildGraph.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: symbolGraph.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try #"{"symbols":[{"names":{"title":"Stale"}}]}"#.write(
            to: staleBuildGraph,
            atomically: true,
            encoding: .utf8
        )
        try #"{"symbols":[]}"#.write(to: symbolGraph, atomically: true, encoding: .utf8)

        let verifier = DocCVerifier(repository: Repository(root: root), buildRoot: scratch)
        #expect(try verifier.requireWaylandClientSymbolGraph().path == symbolGraph.path)
        try verifier.removeWaylandClientSymbolGraphs()

        #expect(!FileManager.default.fileExists(atPath: symbolGraph.path))
        #expect(FileManager.default.fileExists(atPath: staleBuildGraph.path))
    }

    @Test
    func doccVerifierRejectsFailedDumpEvenWhenSymbolGraphExists() throws {
        let root = try temporaryRepository()
        let scratch = root.appendingPathComponent(".scratch")
        let symbolGraph = scratch.appendingPathComponent(
            "debug/symbolgraph/WaylandClient.symbols.json")
        try FileManager.default.createDirectory(
            at: symbolGraph.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try #"{"symbols":[]}"#.write(to: symbolGraph, atomically: true, encoding: .utf8)

        let result = ProcessResult(
            executable: "swift",
            arguments: ["package", "dump-symbol-graph"],
            exitCode: 1,
            stdout: "",
            stderr: "failed target")
        let verifier = DocCVerifier(repository: Repository(root: root), buildRoot: scratch)

        do {
            _ = try verifier.requireWaylandClientSymbolGraph(afterDump: result)
            Issue.record("expected DocC verifier to reject failed symbol graph dump")
        } catch let error as ToolError {
            #expect(error.message.contains("command failed with exit code 1"))
            #expect(error.message.contains("failed target"))
            #expect(error.message.contains("symbol graph was emitted"))
        }
    }

    @Test
    func unsafeAllowlistScansCAndHeaderFilesUnderSources() throws {
        let root = try temporaryRepository()
        let allowlist = root.appendingPathComponent("safety/unsafe-token-allowlist.tsv")
        try FileManager.default.createDirectory(
            at: allowlist.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "".write(to: allowlist, atomically: true, encoding: .utf8)

        let cShim = root.appendingPathComponent("Sources/CExample/shim.c")
        let header = root.appendingPathComponent("Sources/CExample/include/shim.h")
        try FileManager.default.createDirectory(
            at: cShim.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: header.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "int fd = eventfd(0, 0);\n".write(to: cShim, atomically: true, encoding: .utf8)
        try "void *wl_proxy_get_queue(void *proxy);\n".write(
            to: header,
            atomically: true,
            encoding: .utf8
        )

        do {
            try VerificationChecks(
                context: ToolContext(repository: Repository(root: root))
            ).verifyUnsafeAllowlist()
            Issue.record("expected unsafe allowlist verification to reject C/header tokens")
        } catch let error as ToolError {
            #expect(error.message.contains("Sources/CExample/shim.c:1"))
            #expect(error.message.contains("eventfd"))
            #expect(error.message.contains("Sources/CExample/include/shim.h:1"))
            #expect(error.message.contains("wl_proxy_get_queue"))
        }
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-tool-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "".write(
            to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Tests"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Examples"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("protocols"), withIntermediateDirectories: true)
        return root
    }
}
