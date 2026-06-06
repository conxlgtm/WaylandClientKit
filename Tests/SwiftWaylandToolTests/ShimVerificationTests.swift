import Foundation
import SwiftWaylandToolSupport
import Testing

@Suite
struct ShimVerificationTests {
    @Test
    func shimVerificationRejectsMissingImplementationSymbols() throws {
        let root = try temporaryRepository()
        try writeShimTree(
            in: root,
            protocolHeader: "void swl_display_get_registry(void);\n",
            protocolImplementation: ""
        )

        do {
            try VerificationChecks(context: ToolContext(repository: Repository(root: root)))
                .verifyShims()
            Issue.record("expected shim verification to reject missing implementation symbol")
        } catch let error as ToolError {
            #expect(error.message.contains("Missing shim implementation: swl_display_get_registry"))
        }
    }

    @Test
    func shimVerificationRejectsMissingImplementationDirectories() throws {
        let root = try temporaryRepository()
        try writeRequiredHeaders(in: root)

        do {
            try VerificationChecks(context: ToolContext(repository: Repository(root: root)))
                .verifyShims()
            Issue.record("expected shim verification to reject missing implementation directories")
        } catch let error as ToolError {
            let expected =
                "Missing protocol shim implementation directory: Sources/CWaylandProtocols/shims"
            #expect(error.message.contains(expected))
        }
    }

    @Test
    func shimVerificationRejectsHeaderTestingDefaults() throws {
        let root = try temporaryRepository()
        try writeShimTree(
            in: root,
            protocolHeader: "#define SWL_ENABLE_TESTING 1\nvoid swl_display_get_registry(void);\n",
            protocolImplementation: "void swl_display_get_registry(void) {}\n"
        )

        do {
            try VerificationChecks(context: ToolContext(repository: Repository(root: root)))
                .verifyShims()
            Issue.record("expected shim verification to reject header testing defaults")
        } catch let error as ToolError {
            #expect(error.message.contains("Testing shims must be gated by Package.swift"))
        }
    }

    @Test
    func shimVerificationRejectsGBMHeaderTestingDefaults() throws {
        let root = try temporaryRepository()
        try writeShimTree(
            in: root,
            protocolHeader: "void swl_display_get_registry(void);\n",
            protocolImplementation: "void swl_display_get_registry(void) {}\n",
            gbmHeader: "#define NDEBUG 1\n"
        )

        do {
            try VerificationChecks(context: ToolContext(repository: Repository(root: root)))
                .verifyShims()
            Issue.record("expected shim verification to reject GBM header testing defaults")
        } catch let error as ToolError {
            #expect(error.message.contains("swift-wayland-gbm-shims.h"))
        }
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftwayland-shim-verification-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeRequiredHeaders(in root: URL) throws {
        try writeFile(
            root.appendingPathComponent(
                "Sources/CWaylandProtocols/include/swift-wayland-shims.h"),
            text: "")
        try writeFile(
            root.appendingPathComponent(
                "Sources/CWaylandRuntimeShims/include/swift-wayland-runtime-shims.h"),
            text: "")
        try writeFile(
            root.appendingPathComponent(
                "Sources/CWaylandCursorShims/include/swift-wayland-cursor-shims.h"),
            text: "")
        try writeFile(
            root.appendingPathComponent("Sources/CGBMShims/include/swift-wayland-gbm-shims.h"),
            text: "")
    }

    private func writeShimTree(
        in root: URL,
        protocolHeader: String,
        protocolImplementation: String,
        gbmHeader: String = ""
    ) throws {
        try writeFile(
            root.appendingPathComponent(
                "Sources/CWaylandProtocols/include/swift-wayland-shims.h"),
            text: protocolHeader)
        try writeFile(
            root.appendingPathComponent("Sources/CWaylandProtocols/shims/display-core.c"),
            text: protocolImplementation)
        try writeFile(
            root.appendingPathComponent(
                "Sources/CWaylandRuntimeShims/include/swift-wayland-runtime-shims.h"),
            text: "")
        try writeFile(
            root.appendingPathComponent("Sources/CWaylandRuntimeShims/fd-shim.c"),
            text: "")
        try writeFile(
            root.appendingPathComponent(
                "Sources/CWaylandCursorShims/include/swift-wayland-cursor-shims.h"),
            text: "")
        try writeFile(
            root.appendingPathComponent("Sources/CWaylandCursorShims/cursor-shims.c"),
            text: "")
        try writeFile(
            root.appendingPathComponent("Sources/CGBMShims/include/swift-wayland-gbm-shims.h"),
            text: gbmHeader)
    }

    private func writeFile(_ url: URL, text: String) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
