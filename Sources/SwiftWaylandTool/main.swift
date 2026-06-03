import ArgumentParser
import Foundation
import SwiftWaylandToolSupport

@main
struct Swl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swl",
        abstract: "SwiftWayland repository tooling",
        subcommands: [
            Tools.self,
            Protocols.self,
            Docc.self,
            Coverage.self,
            Bootstrap.self,
            Format.self,
            Lint.self,
            Docs.self,
            API.self,
            Imports.self,
            Shims.self,
            Safety.self,
            Test.self,
            Smoke.self,
            CI.self,
        ]
    )
}

private protocol ToolCommand: ParsableCommand {
    var verbose: Bool { get }
}

extension ToolCommand {
    func context() throws -> ToolContext {
        try ToolContext.live(verbose: verbose)
    }
}

struct Tools: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tools",
        subcommands: [Doctor.self, InstallSwiftLint.self]
    )

    struct Doctor: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "doctor")

        @Flag(name: .long)
        var protocolTooling = false

        @Flag(name: .long)
        var nativeDependencies = false

        @Flag(name: .long)
        var verbose = false

        func run() throws {
            try ProjectDoctor(context: context()).run(
                checkProtocolTooling: protocolTooling,
                checkNativeDependencies: nativeDependencies
            )
        }
    }

    struct InstallSwiftLint: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "install-swiftlint")

        @Option
        var destination: String

        @Option
        var version = "0.61.0"

        @Flag(name: .long)
        var verbose = false

        func run() throws {
            let context = try context()
            let architecture = try context.runner.run("uname", ["-m"]).stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let archiveArchitecture: String
            switch architecture {
            case "x86_64", "amd64":
                archiveArchitecture = "amd64"
            case "aarch64", "arm64":
                archiveArchitecture = "arm64"
            default:
                throw ToolError("unsupported SwiftLint architecture: \(architecture)", exitCode: ToolExitCode.environment)
            }

            let temporary = try context.fileSystem.createTemporaryDirectory(prefix: "swiftlint")
            defer { try? context.fileSystem.removeItem(temporary) }
            let archive = temporary.appendingPathComponent("swiftlint.zip")
            let url = "https://github.com/realm/SwiftLint/releases/download/\(version)/swiftlint_linux_\(archiveArchitecture).zip"
            try context.runner.run("curl", ["--fail", "--location", "--silent", "--show-error", url, "--output", archive.path])
            try context.runner.run("unzip", ["-q", archive.path, "-d", temporary.path])
            let candidate = ["swiftlint", "swiftlint-static"]
                .map { temporary.appendingPathComponent($0) }
                .first { context.fileSystem.isExecutable($0) || context.fileSystem.exists($0) }
            guard let candidate else {
                throw ToolError("SwiftLint binary not found in downloaded archive", exitCode: ToolExitCode.data)
            }
            let destinationURL = URL(fileURLWithPath: destination).appendingPathComponent("swiftlint")
            try context.fileSystem.copyItem(at: candidate, to: destinationURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
            let installed = try context.runner.run(destinationURL.path, ["version"]).stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
            context.diagnostics.success("swiftlint \(installed): \(destinationURL.path)")
        }
    }
}

struct Protocols: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "protocols",
        subcommands: [
            List.self,
            Sources.self,
            Sync.self,
            Generate.self,
            VerifyGenerated.self,
            VerifyManifest.self,
        ]
    )

    struct List: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "list")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            let manifest = try ProtocolTooling(repository: context.repository).loadManifest()
            for entry in manifest.protocols {
                context.diagnostics.info("\(entry.name)\t\(entry.swiftWaylandTier)\t\(entry.apiExposure)\t\(entry.localPath)")
            }
        }
    }

    struct Sources: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "sources")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            let tooling = ProtocolTooling(
                repository: context.repository,
                fileSystem: context.fileSystem,
                runner: context.runner,
                diagnostics: context.diagnostics
            )
            for (entry, source) in try tooling.resolvedSources() {
                context.diagnostics.info("\(entry.name)\t\(source?.path ?? "<missing>")")
            }
        }
    }

    struct Sync: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "sync")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try ProtocolTooling(
                repository: context.repository,
                fileSystem: context.fileSystem,
                runner: context.runner,
                diagnostics: context.diagnostics
            ).syncProtocols()
        }
    }

    struct Generate: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "generate")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try ProtocolTooling(
                repository: context.repository,
                fileSystem: context.fileSystem,
                runner: context.runner,
                diagnostics: context.diagnostics
            ).generateProtocols()
        }
    }

    struct VerifyGenerated: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify-generated")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try ProtocolTooling(
                repository: context.repository,
                fileSystem: context.fileSystem,
                runner: context.runner,
                diagnostics: context.diagnostics
            ).verifyGenerated()
        }
    }

    struct VerifyManifest: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify-manifest")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try ProtocolTooling(
                repository: context.repository,
                fileSystem: context.fileSystem,
                runner: context.runner,
                diagnostics: context.diagnostics
            ).validateManifest()
        }
    }
}

struct Docc: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "docc",
        subcommands: [Verify.self, VerifySymbolLinks.self]
    )

    struct Verify: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try DocCVerifier(repository: context.repository, diagnostics: context.diagnostics).verifyCatalogExists()
            _ = try context.swift.runSwift(
                ["package", "dump-symbol-graph", "--minimum-access-level", "public", "--skip-synthesized-members"],
                repository: context.repository,
                requireSuccess: false
            )
            try DocCVerifier(repository: context.repository, diagnostics: context.diagnostics).verifySymbolLinks()
        }
    }

    struct VerifySymbolLinks: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify-symbol-links")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try DocCVerifier(repository: context.repository, diagnostics: context.diagnostics).verifySymbolLinks()
        }
    }
}

struct Coverage: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "coverage", subcommands: [Summarize.self])

    struct Summarize: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "summarize")
        @Argument var coverageJSON: String?
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            context.diagnostics.info(try CoverageSummarizer(repository: context.repository).summarize(explicitPath: coverageJSON))
        }
    }
}

struct Bootstrap: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bootstrap",
        subcommands: [Check.self, MaintainerCheck.self, InstallCommand.self]
    )

    struct Check: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "check")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try BootstrapChecker(context: context()).check()
        }
    }

    struct MaintainerCheck: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "maintainer-check")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try BootstrapChecker(context: context()).check(maintainer: true)
        }
    }

    struct InstallCommand: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "install-command")
        @Option var packageManager: String
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            context.diagnostics.info(try BootstrapChecker(context: context).installCommand(packageManager: packageManager))
        }
    }
}

struct Format: ToolCommand {
    static let configuration = CommandConfiguration(commandName: "format")
    @Flag(name: .long) var verbose = false
    func run() throws {
        try SwiftCommandResolver(context: context()).runFormat(mode: "format")
    }
}

struct Lint: ToolCommand {
    static let configuration = CommandConfiguration(commandName: "lint")
    @Flag(name: .long) var verbose = false
    func run() throws {
        let context = try context()
        let resolver = SwiftCommandResolver(context: context)
        try resolver.runFormat(mode: "lint")
        try resolver.runSwiftLint()
    }
}

struct Docs: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "docs", subcommands: [Verify.self])

    struct Verify: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            let required = [
                "README.md",
                "CONTRIBUTING.md",
                "Sources/WaylandClient/WaylandClient.docc/WaylandClient.md",
                "docs/architecture.md",
                "docs/compositor-matrix.md",
                "docs/generation.md",
                "docs/live-wayland-testing.md",
                "docs/public-api-audit.md",
                "docs/public-api-baseline.md",
                "docs/release.md",
                "docs/strict-memory-safety-audit.md",
            ]
            var failures: [String] = []
            for path in required where !context.fileSystem.exists(context.repository.url(path)) {
                failures.append("Missing documentation file: \(path)")
            }
            guard failures.isEmpty else {
                throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
            }
            context.diagnostics.success("documentation files are present")
        }
    }
}

struct API: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "api", subcommands: [Dump.self, Verify.self])

    struct Dump: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "dump")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            context.diagnostics.info(try PublicAPIAuditor(context: context).dump())
        }
    }

    struct Verify: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify")
        @Flag(name: .long) var update = false
        @Flag(name: .long) var verbose = false
        func run() throws {
            try PublicAPIAuditor(context: context()).verify(update: update)
        }
    }
}

struct Imports: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "imports", subcommands: [Verify.self])

    struct Verify: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try VerificationChecks(context: context()).verifyTargetImports()
        }
    }
}

struct Shims: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "shims", subcommands: [Verify.self, VerifyReleaseSymbols.self])

    struct Verify: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try VerificationChecks(context: context()).verifyShims()
        }
    }

    struct VerifyReleaseSymbols: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify-release-symbols")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try VerificationChecks(context: context()).verifyReleaseShimSymbols()
        }
    }
}

struct Safety: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "safety", subcommands: [VerifyUnsafeAllowlist.self])

    struct VerifyUnsafeAllowlist: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify-unsafe-allowlist")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try VerificationChecks(context: context()).verifyUnsafeAllowlist()
        }
    }
}

struct Test: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        subcommands: [
            Unit.self,
            Release.self,
            TSan.self,
            ASan.self,
            IntegrationPublicAPI.self,
            IntegrationGraphicsPreview.self,
            IntegrationFrameworkHost.self,
            IntegrationTinyUI.self,
        ]
    )

    struct Unit: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "unit")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try context.swift.runSwift(["test", "--no-parallel", "-Xswiftc", "-warnings-as-errors"], repository: context.repository)
        }
    }

    struct Release: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "release")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try context.swift.runSwift(["test", "-c", "release", "--no-parallel"], repository: context.repository)
        }
    }

    struct TSan: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "tsan")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            let suppressions = context.repository.url("safety/tsan-suppressions.txt")
            var env: [String: String] = [:]
            env["TSAN_OPTIONS"] = "detect_deadlocks=0:suppressions=\(suppressions.path)"
            try context.swift.runSwift(["test", "--sanitize=thread", "--no-parallel"], repository: context.repository, environment: env)
        }
    }

    struct ASan: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "asan")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try context.swift.runSwift(["test", "--sanitize=address", "--no-parallel"], repository: context.repository, environment: ["ASAN_OPTIONS": "detect_leaks=0"])
        }
    }

    struct IntegrationPublicAPI: IntegrationCommand {
        static let configuration = CommandConfiguration(commandName: "integration-public-api")
        static let packagePath = "IntegrationTests/PublicAPIClient"
        @Flag(name: .long) var verbose = false
    }

    struct IntegrationGraphicsPreview: IntegrationCommand {
        static let configuration = CommandConfiguration(commandName: "integration-graphics-preview")
        static let packagePath = "IntegrationTests/GraphicsPreviewClient"
        @Flag(name: .long) var verbose = false
    }

    struct IntegrationFrameworkHost: IntegrationCommand {
        static let configuration = CommandConfiguration(commandName: "integration-framework-host")
        static let packagePath = "IntegrationTests/FrameworkHostClient"
        @Flag(name: .long) var verbose = false
    }

    struct IntegrationTinyUI: IntegrationCommand {
        static let configuration = CommandConfiguration(commandName: "integration-tiny-ui")
        static let packagePath = "IntegrationTests/TinyUIPrototype"
        @Flag(name: .long) var verbose = false
    }
}

private protocol IntegrationCommand: ToolCommand {
    static var packagePath: String { get }
}

extension IntegrationCommand {
    func run() throws {
        let context = try context()
        let scratch = try context.fileSystem.createTemporaryDirectory(prefix: "swiftwayland-integration")
        defer { try? context.fileSystem.removeItem(scratch) }
        try context.swift.runSwift(
            ["test", "--package-path", context.repository.url(Self.packagePath).path, "--scratch-path", scratch.path],
            repository: context.repository
        )
    }
}

struct Smoke: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "smoke",
        subcommands: [Live.self, Integration.self, GPUPreview.self, Headless.self]
    )

    struct Live: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "live")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            guard context.runner.environment["WAYLAND_DISPLAY"] != nil else {
                throw ToolError("WAYLAND_DISPLAY is not set; run this under a Wayland session.", exitCode: ToolExitCode.environment)
            }
            try context.swift.runSwift(
                ["run", "--disable-index-store", "swift-wayland-smoke", "--timeout-milliseconds", "5000"],
                repository: context.repository
            )
        }
    }

    struct Integration: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "integration")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            guard context.runner.environment["WAYLAND_DISPLAY"] != nil else {
                throw ToolError("WAYLAND_DISPLAY is not set. Run public integration tests under a Wayland session.", exitCode: ToolExitCode.environment)
            }
            try Test.IntegrationPublicAPI(verbose: verbose).run()
            try context.swift.runSwift(
                ["test", "--filter", "WindowControlPublicRequestTests"],
                repository: context.repository,
                environment: requestTestEnvironment()
            )
            try context.swift.runSwift(
                ["test", "--filter", "WindowDragSourcePublicRequestTests"],
                repository: context.repository,
                environment: requestTestEnvironment()
            )
        }
    }

    struct GPUPreview: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "gpu-preview")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            guard context.runner.environment["WAYLAND_DISPLAY"] != nil else {
                throw ToolError("WAYLAND_DISPLAY is not set. Run GPU preview tests under a Wayland session.", exitCode: ToolExitCode.environment)
            }
            try context.swift.runSwift(
                ["test", "--filter", "GPUPreviewLiveCapability|gpuSmokeDrawsDeterministicPixelWhenEnabled"],
                repository: context.repository,
                environment: ["SWL_RUN_GPU_SMOKE": "1", "SWIFT_WAYLAND_ENABLE_GPU_PREVIEW_TESTS": "1"]
            )
            try context.swift.runSwift(["run", "--disable-index-store", "GPUPreviewSmokeClient"], repository: context.repository)
        }
    }

    struct Headless: ToolCommand {
        static let configuration = CommandConfiguration(
            commandName: "headless",
            shouldDisplay: true
        )

        @Flag(name: .long) var verbose = false
        @Argument(parsing: .remaining) var command: [String]

        func run() throws {
            let context = try context()
            var child = command
            if child.first == "--" {
                child.removeFirst()
            }
            if child.first == "swl" {
                child[0] = try context.runner.executableURL(for: "swift").path
                child.insert(contentsOf: ["run", "swl"], at: 1)
            }
            try HeadlessWestonRunner(context: context).run(command: child)
        }
    }
}

struct CI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ci",
        subcommands: [Cheap.self, CheckBase.self, Check.self, Release.self]
    )

    struct Cheap: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "cheap")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try ProtocolTooling(repository: context.repository, runner: context.runner, diagnostics: context.diagnostics).verifyGenerated()
            try ProtocolTooling(repository: context.repository, diagnostics: context.diagnostics).validateManifest()
            try VerificationChecks(context: context).verifyShims()
            try PublicAPIAuditor(context: context).verify(update: false)
            try VerificationChecks(context: context).verifyTargetImports()
            try VerificationChecks(context: context).verifyUnsafeAllowlist()
        }
    }

    struct CheckBase: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "check-base")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try Lint(verbose: verbose).run()
            try CI.Cheap(verbose: verbose).run()
            try Docs.Verify(verbose: verbose).run()
            try Docc.Verify(verbose: verbose).run()
            try context.swift.runSwift(["build", "--disable-index-store", "-Xswiftc", "-strict-concurrency=complete", "-Xswiftc", "-warn-concurrency"], repository: context.repository)
            try Test.Unit(verbose: verbose).run()
            try Test.IntegrationPublicAPI(verbose: verbose).run()
            try Test.IntegrationGraphicsPreview(verbose: verbose).run()
            try Test.IntegrationFrameworkHost(verbose: verbose).run()
            try Test.IntegrationTinyUI(verbose: verbose).run()
        }
    }

    struct Check: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "check")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try CI.CheckBase(verbose: verbose).run()
            if context.runner.environment["WAYLAND_DISPLAY"] != nil {
                try Smoke.Live(verbose: verbose).run()
            } else {
                context.diagnostics.warning("Skipping live Wayland smoke check because WAYLAND_DISPLAY is not set.")
            }
        }
    }

    struct Release: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "release")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try CI.CheckBase(verbose: verbose).run()
            try context.swift.runSwift(["build", "--disable-index-store", "-c", "release"], repository: context.repository)
            for target in ["SwiftWaylandDemo", "GPUPreviewSmokeClient", "GraphicsPreviewManagedGPUClear", "PointerCaptureSmoke", "CursorPolicySmoke"] {
                try context.swift.runSwift(["build", "--disable-index-store", "-c", "release", "--target", target], repository: context.repository)
            }
            try context.swift.runSwift(["build", "--disable-index-store", "-c", "release", "--product", "swift-wayland-smoke"], repository: context.repository)
            try Test.Release(verbose: verbose).run()
            try VerificationChecks(context: context).verifyReleaseShimSymbols()
            if context.runner.environment["WAYLAND_DISPLAY"] != nil {
                try Smoke.Live(verbose: verbose).run()
                try Smoke.Integration(verbose: verbose).run()
            } else if context.runner.canFind("weston") {
                let swiftPath = try context.runner.executableURL(for: "swift").path
                try HeadlessWestonRunner(context: context).run(command: [swiftPath, "run", "swl", "smoke", "live"])
                try HeadlessWestonRunner(context: context).run(command: [swiftPath, "run", "swl", "smoke", "integration"])
            } else if context.runner.environment["CI"] == "true" || context.runner.environment["REQUIRE_WAYLAND_SMOKE"] == "1" {
                throw ToolError("Wayland checks are required, but WAYLAND_DISPLAY and weston are unavailable.", exitCode: ToolExitCode.environment)
            } else {
                context.diagnostics.warning("Skipping Wayland checks because WAYLAND_DISPLAY is not set and weston is unavailable.")
            }
        }
    }
}

private func requestTestEnvironment() -> [String: String] {
    [
        "SWIFT_WAYLAND_ENABLE_WINDOW_CONTROL_REQUEST_TESTS": "1",
        "SWIFT_WAYLAND_ENABLE_DND_SOURCE_REQUEST_TESTS": "1",
    ]
}
