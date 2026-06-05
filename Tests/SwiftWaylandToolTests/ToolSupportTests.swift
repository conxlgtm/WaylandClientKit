import Foundation
import Synchronization
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
                environment: ["SWIFT_WAYLAND_SWIFTPM_SCRATCH": scratch.path]))

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
    func doccVerifierRemovesStaleWaylandClientSymbolGraphs() throws {
        let root = try temporaryRepository()
        let symbolGraph = root.appendingPathComponent(
            ".build/debug/symbolgraph/WaylandClient.symbols.json")
        try FileManager.default.createDirectory(
            at: symbolGraph.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try #"{"symbols":[]}"#.write(to: symbolGraph, atomically: true, encoding: .utf8)

        let verifier = DocCVerifier(repository: Repository(root: root))
        _ = try verifier.requireWaylandClientSymbolGraph()
        try verifier.removeWaylandClientSymbolGraphs()

        #expect(!FileManager.default.fileExists(atPath: symbolGraph.path))
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

    @Test
    func protocolManifestValidationRejectsEscapingPaths() throws {
        let root = try temporaryRepository()
        try writeProtocolXML(in: root)
        try writeProtocolManifest(
            in: root,
            localPath: "protocols/upstream/../../outside.xml",
            generatedHeaderPath: "Sources/CWaylandProtocols/include/generated/../../escape.h",
            generatedCodePath: "Sources/CWaylandProtocols/generated/core/wayland-protocol.c")

        do {
            try ProtocolTooling(repository: Repository(root: root)).validateManifest()
            Issue.record("expected manifest validation to reject escaping paths")
        } catch let error as ToolError {
            #expect(error.message.contains("localPath must not contain"))
            #expect(error.message.contains("generatedHeaderPath must not contain"))
        }
    }

    @Test
    func protocolManifestValidationRejectsChecksumMismatch() throws {
        let root = try temporaryRepository()
        try writeProtocolXML(in: root)
        try writeProtocolManifest(
            in: root,
            sha256: "0000000000000000000000000000000000000000000000000000000000000000")

        do {
            try ProtocolTooling(repository: Repository(root: root)).validateManifest()
            Issue.record("expected manifest validation to reject checksum mismatch")
        } catch let error as ToolError {
            #expect(error.message.contains("checksum mismatch"))
        }
    }

    @Test
    func protocolSyncRemovesExistingVendoredXMLAndCopiesResolvedSource() throws {
        let root = try temporaryRepository()
        try writeProtocolXML(in: root)
        try writeProtocolManifest(in: root)
        let actualSource = root.appendingPathComponent("system-protocols/store/wayland.xml")
        let source = root.appendingPathComponent("system-protocols/share/wayland.xml")
        try FileManager.default.createDirectory(
            at: actualSource.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: source.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "<protocol name=\"wayland\"/>".write(
            to: actualSource,
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createSymbolicLink(at: source, withDestinationURL: actualSource)

        let fileSystem = CopyRequiresMissingDestinationFileSystem()
        try ProtocolTooling(
            repository: Repository(root: root),
            fileSystem: fileSystem,
            runner: ProcessRunner(environment: ["WAYLAND_CORE_XML_SOURCE": source.path])
        ).syncProtocols()

        let destination = root.appendingPathComponent("protocols/upstream/core/wayland.xml")
            .standardizedFileURL
        #expect(fileSystem.removedPaths.contains(destination.path))
        #expect(fileSystem.copiedDestinations.contains(destination.path))
        #expect(fileSystem.copiedSources.contains(actualSource.resolvingSymlinksInPath().path))
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
            .appendingPathComponent("swiftwayland-tool-tests-\(UUID().uuidString)")
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

    private func writeProtocolXML(in root: URL) throws {
        let xml = root.appendingPathComponent("protocols/upstream/core/wayland.xml")
        try FileManager.default.createDirectory(
            at: xml.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "<protocol name=\"wayland\"/>".write(to: xml, atomically: true, encoding: .utf8)
    }

    private func writeProtocolManifest(
        in root: URL,
        localPath: String = "protocols/upstream/core/wayland.xml",
        generatedHeaderPath: String =
            "Sources/CWaylandProtocols/include/generated/core/wayland-client-protocol.h",
        generatedCodePath: String =
            "Sources/CWaylandProtocols/generated/core/wayland-protocol.c",
        sha256: String = "9ea5e3ec5abc7f3be523aeec121df7f940f84357df40c786ebd0a8f548c5e4ea"
    ) throws {
        let manifest = root.appendingPathComponent("protocols/manifest.json")
        try """
        {
          "protocols": [
            {
              "name": "wayland-core",
              "localPath": "\(localPath)",
              "upstreamProject": "wayland",
              "upstreamVersion": "1",
              "vendoredFromPackage": "pkg",
              "vendoredFromPath": "/tmp/wayland.xml",
              "sha256": "\(sha256)",
              "swiftWaylandTier": "required",
              "apiExposure": "internal",
              "testStrategy": "unit-and-live",
              "notes": "test",
              "sourceResolution": {
                "strategy": "pkg-config-with-fallbacks",
                "environmentOverride": "WAYLAND_CORE_XML_SOURCE",
                "pkgConfigPackage": "wayland-client",
                "pkgConfigVariable": "pkgdatadir",
                "relativeSourceCandidates": ["wayland.xml"],
                "absoluteFallbackCandidates": ["/usr/share/wayland/wayland.xml"]
              },
              "generatedHeaderPath": "\(generatedHeaderPath)",
              "generatedCodePath": "\(generatedCodePath)",
              "scannerHeaderMode": "client-header",
              "scannerCodeMode": "private-code"
            }
          ]
        }
        """.write(to: manifest, atomically: true, encoding: .utf8)
    }

    private final class CopyRequiresMissingDestinationFileSystem: FileSystem {
        private let local = LocalFileSystem()
        private let removedPathStorage = Mutex<[String]>([])
        private let copiedSourceStorage = Mutex<[String]>([])
        private let copiedDestinationStorage = Mutex<[String]>([])

        var removedPaths: [String] {
            removedPathStorage.withLock { $0 }
        }

        var copiedSources: [String] {
            copiedSourceStorage.withLock { $0 }
        }

        var copiedDestinations: [String] {
            copiedDestinationStorage.withLock { $0 }
        }

        func exists(_ url: URL) -> Bool {
            local.exists(url)
        }

        func isDirectory(_ url: URL) -> Bool {
            local.isDirectory(url)
        }

        func isExecutable(_ url: URL) -> Bool {
            local.isExecutable(url)
        }

        func readText(_ url: URL) throws -> String {
            try local.readText(url)
        }

        func readData(_ url: URL) throws -> Data {
            try local.readData(url)
        }

        func writeText(_ text: String, to url: URL) throws {
            try local.writeText(text, to: url)
        }

        func writeData(_ data: Data, to url: URL) throws {
            try local.writeData(data, to: url)
        }

        func createDirectory(_ url: URL) throws {
            try local.createDirectory(url)
        }

        func createTemporaryDirectory(prefix: String) throws -> URL {
            try local.createTemporaryDirectory(prefix: prefix)
        }

        func copyItem(at source: URL, to destination: URL) throws {
            if exists(destination) {
                throw ToolError(
                    "destination was not removed before copy: \(destination.path)",
                    exitCode: ToolExitCode.data
                )
            }
            copiedSourceStorage.withLock { $0.append(source.standardizedFileURL.path) }
            copiedDestinationStorage.withLock { $0.append(destination.standardizedFileURL.path) }
            try local.copyItem(at: source, to: destination)
        }

        func removeItem(_ url: URL) throws {
            removedPathStorage.withLock { $0.append(url.standardizedFileURL.path) }
            try local.removeItem(url)
        }

        func walk(_ root: URL, includingDirectories: Bool) throws -> [URL] {
            try local.walk(root, includingDirectories: includingDirectories)
        }

        func filesEqual(_ lhs: URL, _ rhs: URL) throws -> Bool {
            try local.filesEqual(lhs, rhs)
        }
    }
}
