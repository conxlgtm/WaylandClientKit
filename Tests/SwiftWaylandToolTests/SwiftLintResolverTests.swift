import Foundation
import SwiftWaylandToolSupport
import Testing

@Suite
struct SwiftLintResolverTests {
    @Test
    func fallsBackToNixDevelopWhenPathBinaryCannotRun() throws {
        let root = try temporaryRepository()
        try "".write(
            to: root.appendingPathComponent("flake.nix"),
            atomically: true,
            encoding: .utf8
        )
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try writeExecutable(
            """
            #!/bin/sh
            if [ "$1" = "version" ]; then
              exit 127
            fi
            exit 44
            """,
            to: bin.appendingPathComponent("swiftlint")
        )
        let nixInvocation = root.appendingPathComponent("nix-invocation.txt")
        try writeExecutable(
            """
            #!/bin/sh
            printf '%s\\n' "$@" > \(nixInvocation.path)
            exit 0
            """,
            to: bin.appendingPathComponent("nix")
        )
        let runner = ProcessRunner(
            environment: ["PATH": bin.path, "SWL_NIX_BIN": bin.appendingPathComponent("nix").path])
        let context = ToolContext(repository: Repository(root: root), runner: runner)

        try SwiftCommandResolver(context: context).runSwiftLint()

        let arguments = try String(contentsOf: nixInvocation, encoding: .utf8)
        #expect(arguments.contains("--option\nwarn-dirty\nfalse\ndevelop\n"))
        #expect(arguments.contains("\n--command\nswiftlint\n"))
        #expect(
            arguments.contains(
                "lint\n--strict\n--no-cache\n--force-exclude\n--config\n.swiftlint.yml"))
    }

    @Test
    func prefersNixDevelopOverPathBinaryWhenFlakeSwiftLintIsAvailable() throws {
        let root = try temporaryRepository()
        try "".write(
            to: root.appendingPathComponent("flake.nix"),
            atomically: true,
            encoding: .utf8
        )
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let swiftLintInvocation = root.appendingPathComponent("swiftlint-invocation.txt")
        try writeExecutable(
            """
            #!/bin/sh
            if [ "$1" = "version" ]; then
              exit 0
            fi
            printf '%s\\n' "$@" > \(swiftLintInvocation.path)
            exit 44
            """,
            to: bin.appendingPathComponent("swiftlint")
        )
        let nixInvocation = root.appendingPathComponent("nix-invocation.txt")
        try writeExecutable(
            """
            #!/bin/sh
            printf '%s\\n' "$@" > \(nixInvocation.path)
            exit 0
            """,
            to: bin.appendingPathComponent("nix")
        )
        let runner = ProcessRunner(
            environment: ["PATH": bin.path, "SWL_NIX_BIN": bin.appendingPathComponent("nix").path])
        let context = ToolContext(repository: Repository(root: root), runner: runner)

        try SwiftCommandResolver(context: context).runSwiftLint()

        let arguments = try String(contentsOf: nixInvocation, encoding: .utf8)
        #expect(arguments.contains("--option\nwarn-dirty\nfalse\ndevelop\n"))
        #expect(arguments.contains("\n--command\nswiftlint\n"))
        #expect(
            arguments.contains(
                "lint\n--strict\n--no-cache\n--force-exclude\n--config\n.swiftlint.yml"))
        #expect(!FileManager.default.fileExists(atPath: swiftLintInvocation.path))
    }

    @Test
    func usesPathBinaryWhenVersionProbePasses() throws {
        let root = try temporaryRepository()
        try "".write(
            to: root.appendingPathComponent("flake.nix"),
            atomically: true,
            encoding: .utf8
        )
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let swiftLintInvocation = root.appendingPathComponent("swiftlint-invocation.txt")
        try writeExecutable(
            """
            #!/bin/sh
            if [ "$1" = "version" ]; then
              exit 0
            fi
            printf '%s\\n' "$@" > \(swiftLintInvocation.path)
            exit 0
            """,
            to: bin.appendingPathComponent("swiftlint")
        )
        try writeExecutable(
            """
            #!/bin/sh
            exit 45
            """,
            to: bin.appendingPathComponent("nix")
        )
        let runner = ProcessRunner(
            environment: ["PATH": bin.path, "SWL_NIX_BIN": bin.appendingPathComponent("nix").path])
        let context = ToolContext(repository: Repository(root: root), runner: runner)

        try SwiftCommandResolver(context: context).runSwiftLint()

        let arguments = try String(contentsOf: swiftLintInvocation, encoding: .utf8)
        #expect(
            arguments.contains(
                "lint\n--strict\n--no-cache\n--force-exclude\n--config\n.swiftlint.yml"))
    }

    private func temporaryRepository() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftwayland-swiftlint-tests-\(UUID().uuidString)")
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
