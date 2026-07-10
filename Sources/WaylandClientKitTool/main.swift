import ArgumentParser
import Foundation
import WaylandClientKitToolSupport

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

// ArgumentParser command definitions are property-wrapper dense by design.
// swiftlint:disable attributes file_length function_body_length let_var_whitespace type_name

@main
enum WaylandClientKitToolMain {
    static func main() {
        let environment = ProcessInfo.processInfo.environment
        if CCompilerFilter.isEnabled(environment: environment) {
            runCCompilerFilter(environment: environment)
        }
        Wck.main()
    }

    private static func runCCompilerFilter(environment: [String: String]) -> Never {
        do {
            let result = try CCompilerFilter.run(
                arguments: Array(CommandLine.arguments.dropFirst()),
                environment: environment)
            write(result.stdout, to: FileHandle.standardOutput)
            write(result.stderr, to: FileHandle.standardError)
            exit(result.exitCode)
        } catch let error as ToolError {
            write("Error: \(error.message)\n", to: FileHandle.standardError)
            exit(error.exitCode)
        } catch {
            write("Error: \(error)\n", to: FileHandle.standardError)
            exit(ToolExitCode.failure)
        }
    }

    private static func write(_ text: String, to handle: FileHandle) {
        guard !text.isEmpty, let data = text.data(using: .utf8) else { return }
        handle.write(data)
    }
}

struct Wck: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wck",
        abstract: "WaylandClientKit repository tooling",
        subcommands: [
            Tools.self,
            Protocols.self,
            Docc.self,
            Coverage.self,
            Examples.self,
            Compositor.self,
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

private let swiftLintArchiveChecksums = [
    "0.61.0": [
        "amd64": "02f4f580bbb27fb618dbfa24ce2f14c926461c85c26941289f58340151b63ae4",
        "arm64": "8436629d8088142a52d38a4da6b8a37e53d1428acb4601767cb9dd5b516d0a5d",
    ]
]

extension ToolCommand {
    func context() throws -> ToolContext {
        try ToolContext.live(verbose: verbose)
    }
}

struct Tools: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tools",
        subcommands: [Doctor.self, ToolchainSmokeCommand.self, InstallSwiftLint.self]
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

        @Option
        var checksum: String?

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
                throw ToolError(
                    "unsupported SwiftLint architecture: \(architecture)",
                    exitCode: ToolExitCode.environment)
            }

            let temporary = try context.fileSystem.createTemporaryDirectory(prefix: "swiftlint")
            defer { ignoreCleanupError { try context.fileSystem.removeItem(temporary) } }
            let archive = temporary.appendingPathComponent("swiftlint.zip")
            let url =
                "https://github.com/realm/SwiftLint/releases/download/\(version)/swiftlint_linux_\(archiveArchitecture).zip"
            try context.runner.run(
                "curl",
                ["--fail", "--location", "--silent", "--show-error", url, "--output", archive.path])
            let expectedChecksum: String
            if let checksum {
                expectedChecksum = checksum.lowercased()
            } else if let pinned = swiftLintArchiveChecksums[version]?[archiveArchitecture] {
                expectedChecksum = pinned
            } else {
                throw ToolError(
                    "unsupported SwiftLint artifact: \(version) \(archiveArchitecture). "
                        + "Pass --checksum with the expected SHA-256 digest.",
                    exitCode: ToolExitCode.data)
            }
            guard SHA256Checksum.isValid(expectedChecksum) else {
                throw ToolError(
                    "SwiftLint checksum must be a 64-character lowercase hex digest",
                    exitCode: ToolExitCode.data)
            }
            let actualChecksum = try SHA256Checksum.compute(
                of: archive,
                fileSystem: context.fileSystem)
            guard actualChecksum == expectedChecksum else {
                throw ToolError(
                    "SwiftLint archive checksum mismatch: expected \(expectedChecksum), "
                        + "got \(actualChecksum)",
                    exitCode: ToolExitCode.data)
            }
            try context.runner.run("unzip", ["-q", archive.path, "-d", temporary.path])
            let candidate = ["swiftlint", "swiftlint-static"]
                .map { temporary.appendingPathComponent($0) }
                .first { context.fileSystem.isExecutable($0) || context.fileSystem.exists($0) }
            guard let candidate else {
                throw ToolError(
                    "SwiftLint binary not found in downloaded archive", exitCode: ToolExitCode.data)
            }
            let destinationURL = URL(fileURLWithPath: destination).appendingPathComponent(
                "swiftlint")
            try context.fileSystem.copyItem(at: candidate, to: destinationURL)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
            let installed = try context.runner.run(destinationURL.path, ["version"]).stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
            context.diagnostics.success("swiftlint \(installed): \(destinationURL.path)")
        }
    }

    struct ToolchainSmokeCommand: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "toolchain-smoke")

        @Flag(help: "Skip the allowed-failure Swift Build preview probe.")
        var skipSwiftBuildPreview = false

        @Flag(name: .long)
        var verbose = false

        func run() throws {
            let context = try context()
            context.diagnostics.info(
                try ToolchainSmoke(context: context).report(
                    runSwiftBuildPreview: !skipSwiftBuildPreview))
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
            NormalizeManifest.self,
        ]
    )

    struct List: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "list")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            let manifest = try ProtocolTooling(repository: context.repository).loadManifest()
            for entry in manifest.protocols {
                let summary = [
                    entry.name,
                    entry.waylandClientKitTier,
                    entry.apiExposure,
                    entry.localPath,
                ].joined(separator: "\t")
                context.diagnostics.info(
                    summary
                )
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

    struct NormalizeManifest: ToolCommand {
        static let configuration = CommandConfiguration(
            commandName: "normalize-manifest", shouldDisplay: false)
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try ProtocolTooling(
                repository: context.repository,
                fileSystem: context.fileSystem,
                runner: context.runner,
                diagnostics: context.diagnostics
            ).normalizeManifestMetadata()
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
            try runDoccVerify(context: context())
        }
    }

    struct VerifySymbolLinks: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify-symbol-links")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runDoccSymbolLinks(context: context())
        }
    }
}

struct Coverage: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "coverage", subcommands: [Summarize.self])

    struct Summarize: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "summarize")
        @Argument var coverageJSON: String?
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            context.diagnostics.info(
                try CoverageSummarizer(repository: context.repository).summarize(
                    explicitPath: coverageJSON))
        }
    }
}

struct Examples: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "examples", subcommands: [Build.self])

    struct Build: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "build")
        @Flag(name: .long) var verbose = false

        func run() throws {
            try ExampleBuilder(context: context()).buildAll()
        }
    }
}

struct Compositor: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "compositor", subcommands: [EvidenceSummary.self])

    struct EvidenceSummary: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "evidence-summary")
        @Flag(name: .long) var verbose = false

        func run() throws {
            let context = try context()
            let markdown = try context.fileSystem.readText(
                context.repository.url("docs/compositor-matrix.md"))
            context.diagnostics.info(
                try CompositorEvidenceSummarizer().summarize(markdown: markdown))
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
            context.diagnostics.info(
                try BootstrapChecker(context: context).installCommand(
                    packageManager: packageManager))
        }
    }
}

struct Format: ToolCommand {
    static let configuration = CommandConfiguration(commandName: "format")
    @Flag(name: .long) var verbose = false
    func run() throws {
        try runFormat(context: context())
    }
}

struct Lint: ToolCommand {
    static let configuration = CommandConfiguration(commandName: "lint")
    @Flag(name: .long) var verbose = false
    func run() throws {
        try runLint(context: context())
    }
}

struct Docs: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "docs", subcommands: [Verify.self])

    struct Verify: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runDocsVerify(context: context())
        }
    }
}

struct API: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "api", subcommands: [Dump.self, Verify.self])

    struct Dump: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "dump")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            context.diagnostics.info(
                try PublicAPIAuditor(context: context).dump(
                    environment: compilerFilterEnvironment(context: context)
                )
            )
        }
    }

    struct Verify: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify")
        @Flag(name: .long) var update = false
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try PublicAPIAuditor(context: context).verify(
                update: update,
                environment: compilerFilterEnvironment(context: context)
            )
        }
    }
}

struct Imports: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "imports", subcommands: [Verify.self])

    struct Verify: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "verify")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try VerificationChecks(context: context()).verifyTargetImports()
        }
    }
}

struct Shims: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "shims", subcommands: [Verify.self, VerifyReleaseSymbols.self])

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
    static let configuration = CommandConfiguration(
        commandName: "safety", subcommands: [VerifyUnsafeAllowlist.self])

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
            RequestPaths.self,
            RequestPathsTSan.self,
            RequestPathsASan.self,
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
            try runUnitTests(context: context())
        }
    }

    struct Release: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "release")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runReleaseTests(context: context())
        }
    }

    struct TSan: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "tsan")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            let suppressions = context.repository.url("safety/tsan-suppressions.txt")
            var env: [String: String] = [:]
            env["TSAN_OPTIONS"] = SanitizerOptions.threadSanitizerOptions(
                suppressions: suppressions,
                inherited: context.runner.environment)
            try context.swift.runSwift(
                ["test", "--sanitize=thread", "--jobs", "2", "--no-parallel"],
                repository: context.repository,
                environment: try compilerFilterEnvironment(context: context, base: env))
        }
    }

    struct ASan: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "asan")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            try context.swift.runSwift(
                ["test", "--sanitize=address", "--no-parallel"], repository: context.repository,
                environment: try compilerFilterEnvironment(context: context))
        }
    }

    struct RequestPaths: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "request-paths")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runRequestPathTests(context: context(), sanitizer: .none)
        }
    }

    struct RequestPathsTSan: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "request-paths-tsan")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runRequestPathTests(context: context(), sanitizer: .thread)
        }
    }

    struct RequestPathsASan: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "request-paths-asan")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runRequestPathTests(context: context(), sanitizer: .address)
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
        try runIntegrationPackage(context: context(), packagePath: Self.packagePath)
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
            try runSmokeLive(context: context())
        }
    }

    struct Integration: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "integration")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runSmokeIntegration(context: context())
        }
    }

    struct GPUPreview: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "gpu-preview")
        @Flag(name: .long) var verbose = false
        func run() throws {
            let context = try context()
            guard context.runner.environment["WAYLAND_DISPLAY"] != nil else {
                throw ToolError(
                    "WAYLAND_DISPLAY is not set. Run GPU preview tests under a Wayland session.",
                    exitCode: ToolExitCode.environment)
            }
            try context.swift.runSwift(
                [
                    "test", "--filter",
                    "GPUPreviewLiveCapability|gpuSmokeDrawsDeterministicPixelWhenEnabled",
                ],
                repository: context.repository,
                environment: [
                    "WCK_RUN_GPU_SMOKE": "1", "WAYLAND_CLIENT_KIT_ENABLE_GPU_PREVIEW_TESTS": "1",
                ]
            )
            try context.swift.runSwift(
                ["run", "--disable-index-store", "GPUPreviewSmokeClient"],
                repository: context.repository)
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
            try HeadlessWestonRunner(context: context).run(command: child)
        }
    }
}

struct CI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ci",
        subcommands: [
            Cheap.self, Required.self, CheckBase.self, Check.self, Release.self,
            FoundationCheck.self,
        ]
    )

    struct Cheap: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "cheap")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runCheap(context: context())
        }
    }

    struct Required: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "required")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runRequired(context: context())
        }
    }

    struct CheckBase: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "check-base")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runCheckBase(context: context())
        }
    }

    struct Check: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "check")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runCheck(context: context())
        }
    }

    struct Release: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "release")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runRelease(context: context())
        }
    }

    struct FoundationCheck: ToolCommand {
        static let configuration = CommandConfiguration(commandName: "foundation-check")
        @Flag(name: .long) var verbose = false
        func run() throws {
            try runFoundationCheck(context: context())
        }
    }
}

private func runFormat(context: ToolContext) throws {
    try SwiftCommandResolver(context: context).runFormat(mode: "format")
}

private func runLint(context: ToolContext) throws {
    let resolver = SwiftCommandResolver(context: context)
    try resolver.runFormat(mode: "lint")
    try resolver.runSwiftLint()
}

private func ignoreCleanupError(_ operation: () throws -> Void) {
    do {
        try operation()
    } catch {
        // Cleanup best-effort only.
    }
}

private func runDocsVerify(context: ToolContext) throws {
    try DocumentationCoverageVerifier(
        repository: context.repository,
        fileSystem: context.fileSystem
    ).verify()
    let documentationFiles = try markdownDocumentationFiles(context: context)
    try DocumentationLinkVerifier(
        repository: context.repository,
        fileSystem: context.fileSystem
    ).verify(files: documentationFiles)
    context.diagnostics.success("documentation files and local links are valid")
}

private func markdownDocumentationFiles(context: ToolContext) throws -> [URL] {
    let roots = [
        context.repository.url("README.md"),
        context.repository.url("CONTRIBUTING.md"),
    ]
    let docs = try context.fileSystem.walk(
        context.repository.url("docs"),
        includingDirectories: false
    ).filter { $0.pathExtension == "md" }
    return (roots + docs).sorted { $0.path < $1.path }
}

private func runDoccVerify(context: ToolContext) throws {
    let buildRoot = context.swift.swiftPMBuildRoot(repository: context.repository)
    let verifier = DocCVerifier(
        repository: context.repository,
        buildRoot: buildRoot,
        diagnostics: context.diagnostics
    )
    try verifier.verifyCatalogExists()
    try verifier.removePublicProductSymbolGraphs()
    let result = try context.swift.runSwift(
        [
            "package", "dump-symbol-graph", "--minimum-access-level", "public",
            "--skip-synthesized-members",
        ],
        repository: context.repository,
        environment: try compilerFilterEnvironment(context: context),
        requireSuccess: false
    )
    try verifier.requirePublicProductSymbolGraphs(
        afterDump: result,
        allowingNonProductFailures: true
    )
    try runDoccSymbolLinks(context: context)
}

private func runDoccSymbolLinks(context: ToolContext) throws {
    let verifier = DocCVerifier(
        repository: context.repository,
        buildRoot: context.swift.swiftPMBuildRoot(repository: context.repository),
        diagnostics: context.diagnostics
    )
    try verifier.verifySymbolLinks()
}

private func runUnitTests(context: ToolContext) throws {
    try context.swift.runSwift(
        [
            "test", "--no-parallel",
            "-Xswiftc", "-Xcc",
            "-Xswiftc", "-Wno-macro-redefined",
            "-Xswiftc", "-warnings-as-errors",
        ],
        repository: context.repository,
        environment: try compilerFilterEnvironment(context: context)
    )
}

private func runReleaseTests(context: ToolContext) throws {
    try context.swift.runSwift(
        ["test", "-c", "release", "--no-parallel"],
        repository: context.repository,
        environment: try compilerFilterEnvironment(context: context))
}

private func runIntegrationPackage(
    context: ToolContext,
    packagePath: String,
    environment: [String: String] = [:]
) throws {
    let scratch = try context.fileSystem.createTemporaryDirectory(
        prefix: "waylandclientkit-integration")
    defer { ignoreCleanupError { try context.fileSystem.removeItem(scratch) } }
    try context.swift.runSwift(
        [
            "test", "--enable-index-store", "--package-path",
            context.repository.url(packagePath).path, "--scratch-path", scratch.path,
        ],
        repository: context.repository,
        environment: try compilerFilterEnvironment(context: context, base: environment)
    )
}

private func compilerFilterEnvironment(
    context: ToolContext,
    base: [String: String] = [:]
) throws -> [String: String] {
    try CCompilerFilter.compilerEnvironment(
        filterExecutable: currentExecutableURL(context: context),
        base: base,
        inherited: context.runner.environment)
}

private func currentExecutableURL(context: ToolContext) throws -> URL {
    guard let path = CommandLine.arguments.first, !path.isEmpty else {
        throw ToolError("cannot resolve wck executable path", exitCode: ToolExitCode.environment)
    }
    return try CCompilerFilter.filterExecutableURL(
        commandPath: path,
        workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        runner: context.runner)
}

private func verifyInvalidGraphicsPolicyClientIsRejected(context: ToolContext) throws {
    let scratch = try context.fileSystem.createTemporaryDirectory(
        prefix: "waylandclientkit-invalid-graphics-policy")
    defer { ignoreCleanupError { try context.fileSystem.removeItem(scratch) } }
    let result = try context.swift.runSwift(
        [
            "build", "--disable-index-store", "--package-path",
            context.repository.url("IntegrationTests/InvalidGraphicsPolicyClient").path,
            "--scratch-path", scratch.path,
        ],
        repository: context.repository,
        environment: try compilerFilterEnvironment(context: context),
        requireSuccess: false
    )
    guard result.exitCode != 0 else {
        throw ToolError("invalid graphics policy client unexpectedly compiled")
    }
    let diagnostics = result.stdout + result.stderr
    guard diagnostics.contains("presentationMode"), diagnostics.contains("fallbackPolicy") else {
        throw ToolError(
            "invalid graphics policy client failed before the contradictory policy was checked"
        )
    }
}

private func runSmokeLive(context: ToolContext) throws {
    guard context.runner.environment["WAYLAND_DISPLAY"] != nil else {
        throw ToolError(
            "WAYLAND_DISPLAY is not set; run this under a Wayland session.",
            exitCode: ToolExitCode.environment)
    }
    try context.swift.runSwift(
        [
            "run",
            "--disable-index-store",
            "wayland-client-kit-smoke",
            "--timeout-milliseconds",
            "5000",
        ],
        repository: context.repository
    )
}

private func runSmokeIntegration(context: ToolContext) throws {
    guard context.runner.environment["WAYLAND_DISPLAY"] != nil else {
        throw ToolError(
            "WAYLAND_DISPLAY is not set. Run public integration tests under a Wayland session.",
            exitCode: ToolExitCode.environment)
    }
    try runIntegrationPackage(
        context: context,
        packagePath: Test.IntegrationPublicAPI.packagePath,
        environment: ["WAYLAND_CLIENT_KIT_ENABLE_PUBLIC_INTEGRATION_TESTS": "1"])
    try runRequestPathTests(context: context, sanitizer: .none)
}

private enum RequestPathSanitizer {
    case none
    case thread
    case address
}

private func runRequestPathTests(context: ToolContext, sanitizer: RequestPathSanitizer) throws {
    guard context.runner.environment["WAYLAND_DISPLAY"] != nil else {
        throw ToolError(
            "WAYLAND_DISPLAY is not set. Run request-path tests under a Wayland session.",
            exitCode: ToolExitCode.environment)
    }

    var arguments = ["test"]
    var environment = requestTestEnvironment()
    switch sanitizer {
    case .none:
        break
    case .thread:
        let suppressions = context.repository.url("safety/tsan-suppressions.txt")
        arguments.append(contentsOf: ["--sanitize=thread", "--jobs", "2", "--no-parallel"])
        environment["TSAN_OPTIONS"] = SanitizerOptions.threadSanitizerOptions(
            suppressions: suppressions,
            inherited: context.runner.environment)
    case .address:
        arguments.append(contentsOf: ["--sanitize=address", "--no-parallel"])
        environment["ASAN_OPTIONS"] = "detect_leaks=0"
    }

    for filter in ["WindowControlPublicRequestTests", "WindowDragSourcePublicRequestTests"] {
        try context.swift.runSwift(
            arguments + ["--filter", filter],
            repository: context.repository,
            environment: try compilerFilterEnvironment(context: context, base: environment)
        )
    }
}

private func runHeadlessWck(context: ToolContext, arguments: [String]) throws {
    let swiftPath = try context.swift.swiftExecutable(environment: context.runner.environment)
    try HeadlessWestonRunner(context: context).run(command: [swiftPath, "run", "wck"] + arguments)
}

private func runHeadlessWaylandReleaseChecks(context: ToolContext) throws {
    try runHeadlessWck(context: context, arguments: ["smoke", "live"])
    try runHeadlessWck(context: context, arguments: ["smoke", "integration"])
    try runHeadlessWck(context: context, arguments: ["test", "request-paths-tsan"])
    try runHeadlessWck(context: context, arguments: ["test", "request-paths-asan"])
}

private func runLiveWaylandReleaseChecks(context: ToolContext) throws {
    try runSmokeLive(context: context)
    try runSmokeIntegration(context: context)
    try runRequestPathTests(context: context, sanitizer: .thread)
    try runRequestPathTests(context: context, sanitizer: .address)
}

private func runCheap(context: ToolContext) throws {
    try runLint(context: context)
    try ProtocolTooling(
        repository: context.repository, runner: context.runner, diagnostics: context.diagnostics
    ).verifyGenerated()
    try ProtocolTooling(repository: context.repository, diagnostics: context.diagnostics)
        .validateManifest()
    try VerificationChecks(context: context).verifyShims()
    try VerificationChecks(context: context).verifyTargetImports()
    try VerificationChecks(context: context).verifyToolDependencyBoundaries()
    try VerificationChecks(context: context).verifyUnsafeAllowlist()
}

private func runRequired(context: ToolContext) throws {
    try PublicAPIAuditor(context: context).verify(
        update: false,
        environment: compilerFilterEnvironment(context: context)
    )
    try context.swift.runSwift(
        [
            "build", "--disable-index-store", "-Xswiftc", "-strict-concurrency=complete",
            "-Xswiftc", "-warn-concurrency",
        ],
        repository: context.repository
    )
    try runUnitTests(context: context)
    try runIntegrationPackage(context: context, packagePath: Test.IntegrationPublicAPI.packagePath)
    try runIntegrationPackage(
        context: context, packagePath: Test.IntegrationGraphicsPreview.packagePath)
    try runIntegrationPackage(
        context: context, packagePath: Test.IntegrationFrameworkHost.packagePath)
    try runIntegrationPackage(context: context, packagePath: Test.IntegrationTinyUI.packagePath)
    try verifyInvalidGraphicsPolicyClientIsRejected(context: context)
}

private func runCheckBase(context: ToolContext) throws {
    try runCheap(context: context)
    try runDocsVerify(context: context)
    try runDoccVerify(context: context)
    try runRequired(context: context)
}

private func runCheck(context: ToolContext) throws {
    try runCheckBase(context: context)
    if context.runner.environment["WAYLAND_DISPLAY"] != nil {
        try runSmokeLive(context: context)
    } else {
        context.diagnostics.warning(
            "Skipping live Wayland smoke check because WAYLAND_DISPLAY is not set.")
    }
}

private func runRelease(context: ToolContext) throws {
    try runCheckBase(context: context)
    try context.swift.runSwift(
        ["build", "--disable-index-store", "-c", "release"], repository: context.repository)
    try ExampleBuilder(context: context).buildAll()
    try context.swift.runSwift(
        [
            "build",
            "--disable-index-store",
            "-c",
            "release",
            "--product",
            "wayland-client-kit-smoke",
        ],
        repository: context.repository)
    try runReleaseTests(context: context)
    try VerificationChecks(context: context).verifyReleaseShimSymbols()
    if context.runner.environment["WAYLAND_DISPLAY"] != nil {
        try runLiveWaylandReleaseChecks(context: context)
    } else if context.runner.canFind("weston") {
        try runHeadlessWaylandReleaseChecks(context: context)
    } else if context.runner.environment["CI"] == "true"
        || context.runner.environment["REQUIRE_WAYLAND_SMOKE"] == "1"
    {
        throw ToolError(
            "Wayland checks are required, but WAYLAND_DISPLAY and weston are unavailable.",
            exitCode: ToolExitCode.environment)
    } else {
        context.diagnostics.warning(
            "Skipping Wayland checks because WAYLAND_DISPLAY is not set and weston is unavailable.")
    }
}

private func runFoundationCheck(context: ToolContext) throws {
    context.diagnostics.info(
        try ToolchainSmoke(context: context).report(runSwiftBuildPreview: true))
    try runCheckBase(context: context)
    try context.swift.runSwift(
        ["build", "--disable-index-store", "-c", "release"],
        repository: context.repository)
    try ExampleBuilder(context: context).buildAll()
    try VerificationChecks(context: context).verifyReleaseShimSymbols()

    let matrixURL = context.repository.url("docs/compositor-matrix.md")
    let markdown = try context.fileSystem.readText(matrixURL)
    let summary = try CompositorEvidenceSummarizer().summarize(markdown: markdown)
    context.diagnostics.info(summary)
    try CompositorEvidenceCompletenessVerifier().verify(markdown: markdown)
}

private func requestTestEnvironment() -> [String: String] {
    [
        "WAYLAND_CLIENT_KIT_ENABLE_WINDOW_CONTROL_REQUEST_TESTS": "1",
        "WAYLAND_CLIENT_KIT_ENABLE_DND_SOURCE_REQUEST_TESTS": "1",
    ]
}

// swiftlint:enable attributes file_length function_body_length let_var_whitespace type_name
