import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct ProtocolToolingTests {
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
              "waylandClientKitTier": "required",
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
              "waylandClientKitTier": "required",
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
    func protocolManifestValidationRejectsSymlinkedLocalPath() throws {
        let root = try temporaryRepository()
        let actualXML = root.appendingPathComponent("outside/wayland.xml")
        let localXML = root.appendingPathComponent("protocols/upstream/core/wayland.xml")
        try FileManager.default.createDirectory(
            at: actualXML.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: localXML.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "<protocol name=\"wayland\"/>".write(to: actualXML, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: localXML, withDestinationURL: actualXML)
        try writeProtocolManifest(in: root)

        do {
            try ProtocolTooling(repository: Repository(root: root)).validateManifest()
            Issue.record("expected manifest validation to reject symlinked localPath")
        } catch let error as ToolError {
            #expect(error.message.contains("localPath must not be a symlink"))
        }
    }

    @Test
    func protocolSyncRemovesExistingVendoredXMLAndWritesRegularFileFromSymlinkSource() throws {
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

        try ProtocolTooling(
            repository: Repository(root: root),
            runner: ProcessRunner(environment: ["WAYLAND_CORE_XML_SOURCE": source.path])
        ).syncProtocols()

        let destination = root.appendingPathComponent("protocols/upstream/core/wayland.xml")
            .standardizedFileURL
        let destinationText = try String(contentsOf: destination, encoding: .utf8)
        #expect(destinationText == "<protocol name=\"wayland\"/>")
        let isSymlink =
            try destination.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true
        #expect(!isSymlink)
    }

    @Test
    func protocolGenerationResolvesWaylandScannerFromNixDevelop() throws {
        let root = try temporaryRepository()
        try "".write(
            to: root.appendingPathComponent("flake.nix"),
            atomically: true,
            encoding: .utf8
        )
        try writeProtocolXML(in: root)
        try writeProtocolManifest(in: root)
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let scanner = bin.appendingPathComponent("wayland-scanner")
        let scannerInvocations = root.appendingPathComponent("scanner-invocations.txt")
        try writeExecutable(
            """
            #!/bin/sh
            if [ "$1" = "--version" ]; then
              echo "wayland-scanner 1.25.0"
              exit 0
            fi
            printf '%s\\n' "$1" >> \(scannerInvocations.path)
            printf '/* Generated by wayland-scanner 1.25.0 */\\n' > "$3"
            exit 0
            """,
            to: scanner
        )
        try writeExecutable(
            """
            #!/bin/sh
            echo \(scanner.path)
            exit 0
            """,
            to: bin.appendingPathComponent("nix")
        )
        let runner = ProcessRunner(
            environment: [
                "PATH": "",
                "SWL_NIX_BIN": bin.appendingPathComponent("nix").path,
            ])

        try ProtocolTooling(repository: Repository(root: root), runner: runner).generateProtocols()

        let invocations = try String(contentsOf: scannerInvocations, encoding: .utf8)
        #expect(invocations.contains("client-header"))
        #expect(invocations.contains("private-code"))
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-protocol-tooling-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "".write(
            to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
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
              "waylandClientKitTier": "required",
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

    private func writeExecutable(_ contents: String, to url: URL) throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
    }
}
