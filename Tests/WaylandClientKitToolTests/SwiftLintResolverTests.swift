import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct SwiftLintResolverTests {
    @Test
    func rejectsSwiftLintWithoutCustomRules() throws {
        let root = try temporaryRepository()
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try writeExecutable(
            """
            #!/bin/sh
            if [ "$1" = "version" ]; then
              exit 0
            fi
            echo "warning: Skipping enabled rule 'custom_rules'" >&2
            exit 0
            """,
            to: bin.appendingPathComponent("swiftlint")
        )
        let runner = ProcessRunner(environment: ["PATH": bin.path])
        let context = ToolContext(repository: Repository(root: root), runner: runner)

        do {
            try SwiftCommandResolver(context: context).runSwiftLint()
            Issue.record("expected non-strict SwiftLint to fail")
        } catch let error as ToolError {
            #expect(error.message.contains("SourceKit custom_rules"))
            #expect(error.message.contains("install-swiftlint"))
        }
    }

    @Test
    func prefersPinnedSwiftLint() throws {
        let root = try temporaryRepository()
        let pinned = root.appendingPathComponent(".build/tools")
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: pinned, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let pinnedInvocation = root.appendingPathComponent("pinned-swiftlint-invocation.txt")
        let pathInvocation = root.appendingPathComponent("path-swiftlint-invocation.txt")
        try writeExecutable(
            strictSwiftLintScript(invocation: pinnedInvocation),
            to: pinned.appendingPathComponent("swiftlint")
        )
        try writeExecutable(
            strictSwiftLintScript(invocation: pathInvocation),
            to: bin.appendingPathComponent("swiftlint")
        )
        let runner = ProcessRunner(environment: ["PATH": bin.path])
        let context = ToolContext(repository: Repository(root: root), runner: runner)

        try SwiftCommandResolver(context: context).runSwiftLint()

        #expect(FileManager.default.fileExists(atPath: pinnedInvocation.path))
        #expect(!FileManager.default.fileExists(atPath: pathInvocation.path))
    }

    @Test
    func usesPathSwiftLintWhenStrict() throws {
        let root = try temporaryRepository()
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let invocation = root.appendingPathComponent("swiftlint-invocation.txt")
        try writeExecutable(
            strictSwiftLintScript(invocation: invocation),
            to: bin.appendingPathComponent("swiftlint")
        )
        let runner = ProcessRunner(environment: ["PATH": bin.path])
        let context = ToolContext(repository: Repository(root: root), runner: runner)

        try SwiftCommandResolver(context: context).runSwiftLint()

        let arguments = try String(contentsOf: invocation, encoding: .utf8)
        #expect(
            arguments.contains(
                "lint\n--strict\n--no-cache\n--quiet\n--force-exclude\n--config\n"
                    + ".swiftlint.yml"))
    }

    private func strictSwiftLintScript(invocation: URL) -> String {
        """
        #!/bin/sh
        if [ "$1" = "version" ]; then
          exit 0
        fi
        for arg in "$@"; do
          case "$arg" in
            *swiftlint-custom-rules-probe*)
              echo "error: No Silent optional try Violation (no_silent_try_optional)" >&2
              exit 1
              ;;
          esac
        done
        printf '%s\\n' "$@" > \(invocation.path)
        exit 0
        """
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("waylandclientkit-swiftlint-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeExecutable(_ contents: String, to url: URL) throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
    }
}
