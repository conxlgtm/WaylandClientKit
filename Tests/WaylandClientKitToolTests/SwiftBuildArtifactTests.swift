import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct SwiftBuildArtifactTests {
    @Test
    func discoversEveryRunnerOnlyInSelectedProducts() throws {
        let root = try temporaryRoot()
        defer { ignoreCleanupError { try FileManager.default.removeItem(at: root) } }
        let products = root.appendingPathComponent("out/Products/Debug-linux-aarch64")
        for path in ["A-test-runner", "B-test-runner", "nested/Stale-test-runner"] {
            try executable(products.appendingPathComponent(path), text: "#!/bin/sh\nexit 0\n")
        }
        try executable(
            root.appendingPathComponent("aarch64/debug/OldPackageTests.xctest"),
            text: "#!/bin/sh\nexit 0\n")
        let artifacts = try SwiftBuildArtifacts(buildRoot: root, productsDirectory: products)
        #expect(
            try artifacts.testRunners().map(\.lastPathComponent) == [
                "A-test-runner", "B-test-runner",
            ])
    }

    @Test
    func rejectsProductsOutsideScratchTree() throws {
        let root = try temporaryRoot()
        defer { ignoreCleanupError { try FileManager.default.removeItem(at: root) } }
        #expect(throws: ToolError.self) {
            try SwiftBuildArtifacts(
                buildRoot: root, productsDirectory: root.deletingLastPathComponent())
        }
    }

    @Test
    func releaseObjectsRequireEachTargetAndIgnoreStaleObjects() throws {
        let root = try temporaryRoot()
        defer { ignoreCleanupError { try FileManager.default.removeItem(at: root) } }
        let products = root.appendingPathComponent("out/Products/Release-linux-aarch64")
        let objectRoot = root.appendingPathComponent(
            "out/Intermediates.noindex/Fixture.build/Release-linux-aarch64/"
                + "CWaylandProtocols-t.build/Objects-normal/aarch64")
        let current = objectRoot.appendingPathComponent("current.o")
        let stale = objectRoot.appendingPathComponent("stale.o")
        try write("", to: current)
        try write("", to: stale)
        try write(
            current.path + "\n",
            to: objectRoot.appendingPathComponent("CWaylandProtocols.LinkFileList"))
        let artifacts = try SwiftBuildArtifacts(buildRoot: root, productsDirectory: products)
        #expect(try artifacts.releaseObjects(target: "CWaylandProtocols") == [current])
        #expect(throws: ToolError.self) { try artifacts.releaseObjects(target: "CGBMShims") }
        try FileManager.default.removeItem(at: current)
        #expect(throws: ToolError.self) {
            try artifacts.releaseObjects(target: "CWaylandProtocols")
        }
    }

    #if os(Linux)

        @Test
        func filteredExecutionRunsOnlyTargetsOwningMatchingTests() throws {
            try withToolProcessFixtureLock {
                try verifyFilteredRunnerSelection()
            }
        }

        private func verifyFilteredRunnerSelection() throws {
            let root = try temporaryRoot()
            defer { ignoreCleanupError { try FileManager.default.removeItem(at: root) } }
            let products = root.appendingPathComponent("out/Products/Debug-linux-x86_64")
            let bin = root.appendingPathComponent("bin")
            let log = root.appendingPathComponent("invocations")
            try executable(
                bin.appendingPathComponent("setarch"),
                text: "#!/bin/sh\nshift 2\nexec \"$@\"\n")
            for (name, suite) in [("A", "FirstSuite"), ("B", "SecondSuite")] {
                try executable(
                    products.appendingPathComponent(name + "-test-runner"),
                    text: """
                        #!/bin/sh
                        if test "$1" = '--list-tests'; then
                            printf '%s\\n' 'Fixture\(name).\(suite)/test()'
                            exit 0
                        fi
                        printf '%s\\n' '\(name)' >> "$RUNNER_LOG"
                        """)
            }
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = bin.path + ":" + environment["PATH", default: ""]
            let artifacts = try SwiftBuildArtifacts(
                buildRoot: root, productsDirectory: products)
            let runner = ProcessRunner(environment: environment)
            try artifacts.runThreadSanitizerTests(
                runner: runner, repository: Repository(root: root),
                environment: ["RUNNER_LOG": log.path],
                filters: ["^FixtureA\\.FirstSuite/", "SecondSuite"])
            #expect(try String(contentsOf: log, encoding: .utf8) == "A\nB\n")
            #expect(throws: ToolError.self) {
                try artifacts.runThreadSanitizerTests(
                    runner: runner, repository: Repository(root: root),
                    environment: ["RUNNER_LOG": log.path], filters: ["MissingSuite"])
            }
            #expect(try String(contentsOf: log, encoding: .utf8) == "A\nB\n")
        }

        @Test
        func runsRemainingTargetsAfterFailure() throws {
            try withToolProcessFixtureLock {
                let root = try temporaryRoot()
                defer { ignoreCleanupError { try FileManager.default.removeItem(at: root) } }
                let products = root.appendingPathComponent("out/Products/Debug-linux-x86_64")
                let bin = root.appendingPathComponent("bin")
                let log = root.appendingPathComponent("invocations")
                try executable(
                    bin.appendingPathComponent("setarch"),
                    text: "#!/bin/sh\nshift 2\nexec \"$@\"\n")
                for (name, status) in [("A", 7), ("B", 0)] {
                    try executable(
                        products.appendingPathComponent(name + "-test-runner"),
                        text:
                            "#!/bin/sh\nprintf '%s\\n' '\(name)' >> \"$RUNNER_LOG\"\n"
                            + "exit \(status)\n"
                    )
                }
                var environment = ProcessInfo.processInfo.environment
                environment["PATH"] = bin.path + ":" + environment["PATH", default: ""]
                let artifacts = try SwiftBuildArtifacts(
                    buildRoot: root, productsDirectory: products)
                #expect(throws: ToolError.self) {
                    try artifacts.runThreadSanitizerTests(
                        runner: ProcessRunner(environment: environment),
                        repository: Repository(root: root),
                        environment: ["RUNNER_LOG": log.path], filters: [])
                }
                #expect(try String(contentsOf: log, encoding: .utf8) == "A\nB\n")
            }
        }
    #endif

    @Test
    func symbolGraphCleanupHandlesBackendPathsAndRejectsAmbiguousGraphs() throws {
        let root = try temporaryRoot()
        defer { ignoreCleanupError { try FileManager.default.removeItem(at: root) } }
        let first = root.appendingPathComponent(
            "out/Products/Debug-linux-aarch64/symbolgraph/WaylandClient.symbols.json")
        let stale = root.appendingPathComponent("aarch64/symbolgraph/WaylandClient.symbols.json")
        try write(#"{"symbols":[]}"#, to: first)
        try write(#"{"symbols":[]}"#, to: stale)
        let verifier = DocCVerifier(repository: Repository(root: root), buildRoot: root)
        #expect(throws: ToolError.self) { try verifier.requireWaylandClientSymbolGraph() }
        try verifier.removeWaylandClientSymbolGraphs()
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(!FileManager.default.fileExists(atPath: stale.path))
        try write(#"{"symbols":[]}"#, to: first)
        #expect(try verifier.requireWaylandClientSymbolGraph() == first)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func executable(_ url: URL, text: String) throws {
        let shell = try ProcessRunner().executableURL(for: "sh").path
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw ToolError("Cannot create executable fixture: \(url.path)")
        }
        let handle = try FileHandle(forWritingTo: url)
        try handle.write(
            contentsOf: Data(text.replacingOccurrences(of: "#!/bin/sh", with: "#!\(shell)").utf8))
        try handle.close()
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func ignoreCleanupError(_ operation: () throws -> Void) {
        do { try operation() } catch { Issue.record("Fixture cleanup failed: \(error)") }
    }
}
