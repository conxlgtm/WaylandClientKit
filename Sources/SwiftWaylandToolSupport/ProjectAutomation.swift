import Foundation

#if os(Linux)
    import Glibc
#endif

// This file coordinates repository-wide checks; each checker is still typed and testable.
// swiftlint:disable file_length function_body_length

private let unsafeTokenPattern = [
    #"@unchecked\s+Sendable"#,
    "UnsafeMutableRawBufferPointer",
    "UnsafeMutableBufferPointer",
    "UnsafeRawBufferPointer",
    "UnsafeBufferPointer",
    "UnsafeMutableRawPointer",
    "UnsafeMutablePointer",
    "UnsafeRawPointer",
    "UnsafePointer",
    "OpaquePointer",
    "Unmanaged",
    "unsafeBitCast",
    "withUnsafeCurrentTask",
    #"nonisolated\(unsafe\)"#,
    #"unowned\(unsafe\)"#,
    #"pthread_[A-Za-z0-9_]+"#,
    "eventfd",
    #"ppoll\("#,
    #"poll\("#,
    #"\bwl_display_dispatch\b"#,
    #"\bwl_display_dispatch_pending\b"#,
    #"\bwl_display_prepare_read\b"#,
    "wl_proxy_add_listener",
    #"\bwl_proxy_get_queue\b"#,
    #"\bwl_proxy_set_queue\b"#,
    #"\bwl_proxy_create_wrapper\b"#,
    #"\bwl_proxy_wrapper_destroy\b"#,
    "swl_proxy_get_queue_raw",
    "UnsafeDefaultQueueEventLoop",
    #"EventLoop\.pumpOnce\(display:"#,
].joined(separator: "|")

public struct ToolContext {
    public let repository: Repository
    public let fileSystem: FileSystem
    public let diagnostics: Diagnostics
    public let runner: ProcessRunner
    public let swift: SwiftToolchain

    public init(
        repository: Repository,
        fileSystem: FileSystem = LocalFileSystem(),
        diagnostics: Diagnostics = Diagnostics(),
        runner: ProcessRunner? = nil
    ) {
        self.repository = repository
        self.fileSystem = fileSystem
        self.diagnostics = diagnostics
        let processRunner = runner ?? ProcessRunner(diagnostics: diagnostics)
        self.runner = processRunner
        self.swift = SwiftToolchain(runner: processRunner)
    }

    public static func live(verbose: Bool = false) throws -> ToolContext {
        let diagnostics = Diagnostics(isVerbose: verbose)
        let repository = try Repository.detect()
        return ToolContext(repository: repository, diagnostics: diagnostics)
    }
}

public struct ProjectDoctor {
    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    public func run(checkProtocolTooling: Bool, checkNativeDependencies: Bool) throws {
        let required = ["Package.swift", "Sources", "Tests", "Examples", "protocols"]
        for path in required {
            let url = context.repository.url(path)
            guard context.fileSystem.exists(url) else {
                throw ToolError(
                    "missing required repository path: \(path)", exitCode: ToolExitCode.environment)
            }
            context.diagnostics.success(path)
        }

        _ = try context.swift.swiftExecutable(environment: context.runner.environment)
        context.diagnostics.success("Swift executable is discoverable")

        if checkProtocolTooling {
            _ = try context.runner.executableURL(for: "wayland-scanner")
            context.diagnostics.success("wayland-scanner is discoverable")
        }

        if checkNativeDependencies {
            _ = try context.runner.executableURL(for: "pkg-config")
            context.diagnostics.success("pkg-config is discoverable")
        }
    }
}

public struct BootstrapChecker {
    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    public func check(maintainer: Bool = false) throws {
        _ = try context.swift.version(repository: context.repository)
        context.diagnostics.success("Swift toolchain")
        _ = try context.swift.runSwift(
            ["package", "describe", "--type", "json"], repository: context.repository)
        context.diagnostics.success("SwiftPM")
        _ = try context.runner.executableURL(for: "pkg-config")
        context.diagnostics.success("pkg-config")

        for module in [
            "wayland-client", "wayland-server", "wayland-cursor", "wayland-egl", "xkbcommon",
            "libdrm", "gbm", "egl", "glesv2",
        ] {
            let result = try context.runner.run(
                "pkg-config",
                ["--exists", module],
                workingDirectory: context.repository.root,
                requireSuccess: false
            )
            guard result.exitCode == 0 else {
                throw ToolError(
                    "missing pkg-config module: \(module)", exitCode: ToolExitCode.environment)
            }
            context.diagnostics.success(module)
        }

        for tool in ["wayland-scanner", "weston", "swiftlint"] {
            if context.runner.canFind(tool) {
                context.diagnostics.success(tool)
            } else if tool == "weston" || tool == "swiftlint" {
                context.diagnostics.warning(
                    "\(tool) is not installed; related checks will fail when requested")
            } else {
                throw ToolError(
                    "missing required tool: \(tool)", exitCode: ToolExitCode.environment)
            }
        }

        if canResolveSwiftFormat() {
            context.diagnostics.success("swift-format")
        } else {
            context.diagnostics.warning("swift-format is not installed")
        }

        if maintainer {
            let resolvedSources = try ProtocolTooling(
                repository: context.repository,
                fileSystem: context.fileSystem,
                runner: context.runner,
                diagnostics: context.diagnostics
            ).resolvedSources()
            for (entry, source) in resolvedSources {
                guard let source else {
                    throw ToolError(
                        "missing protocol source for \(entry.name)",
                        exitCode: ToolExitCode.environment)
                }
                context.diagnostics.success("\(entry.name): \(source.path)")
            }
        }
    }

    public func installCommand(packageManager: String) throws -> String {
        guard let packages = BootstrapPackages.packages[packageManager] else {
            throw ToolError(
                "unsupported package manager: \(packageManager)", exitCode: ToolExitCode.usage)
        }
        switch packageManager {
        case "apt-get":
            return "sudo apt-get update\nsudo apt-get install -y \(packages.joined(separator: " "))"
        case "dnf":
            return "sudo dnf install -y \(packages.joined(separator: " "))"
        case "pacman":
            return "sudo pacman -S --needed --noconfirm \(packages.joined(separator: " "))"
        case "zypper":
            return "sudo zypper --non-interactive install \(packages.joined(separator: " "))"
        case "apk":
            return "sudo apk add \(packages.joined(separator: " "))"
        case "emerge":
            return "sudo emerge --ask=n --verbose \(packages.joined(separator: " "))"
        case "nix":
            return "nix develop"
        default:
            throw ToolError(
                "unsupported package manager: \(packageManager)", exitCode: ToolExitCode.usage)
        }
    }

    private func canResolveSwiftFormat() -> Bool {
        if let override = context.runner.environment["SWIFT_FORMAT_BIN"], !override.isEmpty {
            return context.fileSystem.isExecutable(URL(fileURLWithPath: override))
        }
        if context.runner.canFind("swift-format") {
            return true
        }
        let result = try? context.runner.run(
            "swift", ["format", "--version"], requireSuccess: false)
        return result?.exitCode == 0
    }
}

public enum BootstrapPackages {
    public static let packages: [String: [String]] = [
        "apt-get": [
            "clang", "git", "libdrm-dev", "libegl-dev", "libgbm-dev", "libgles-dev",
            "libwayland-dev", "libxkbcommon-dev", "pkg-config", "ripgrep", "wayland-protocols",
            "weston", "curl", "unzip", "just",
        ],
        "dnf": [
            "clang", "git", "libdrm-devel", "mesa-libEGL-devel", "mesa-libgbm-devel",
            "mesa-libGLES-devel", "wayland-devel", "wayland-protocols-devel", "libxkbcommon-devel",
            "pkgconf-pkg-config", "ripgrep", "weston", "curl", "unzip", "just",
        ],
        "pacman": [
            "clang", "git", "libdrm", "mesa", "wayland", "wayland-protocols", "libxkbcommon",
            "pkgconf", "ripgrep", "weston", "curl", "unzip", "just",
        ],
        "zypper": [
            "clang", "git", "libdrm-devel", "Mesa-libEGL-devel", "libgbm-devel",
            "Mesa-libGLESv2-devel", "wayland-devel", "wayland-protocols-devel",
            "libxkbcommon-devel", "pkgconf-pkg-config", "ripgrep", "weston", "curl", "unzip",
            "just",
        ],
        "apk": [
            "clang", "git", "libdrm-dev", "mesa-dev", "wayland-dev", "wayland-protocols",
            "libxkbcommon-dev", "pkgconf", "ripgrep", "weston", "curl", "unzip", "just",
        ],
        "emerge": [
            "sys-devel/clang", "dev-vcs/git", "x11-libs/libdrm", "media-libs/mesa",
            "dev-libs/wayland", "dev-libs/wayland-protocols", "dev-util/wayland-scanner",
            "x11-libs/libxkbcommon", "virtual/pkgconfig", "sys-apps/ripgrep", "gui-libs/weston",
            "net-misc/curl", "app-arch/unzip",
        ],
        "nix": [],
    ]
}

public struct SwiftCommandResolver {
    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    public func runSwift(_ arguments: [String], environment: [String: String] = [:]) throws {
        try context.swift.runSwift(
            arguments, repository: context.repository, environment: environment)
    }

    public func runFormat(mode: String) throws {
        let files = [
            "Package.swift",
            "IntegrationTests/PublicAPIClient/Package.swift",
            "IntegrationTests/GraphicsPreviewClient/Package.swift",
            "IntegrationTests/FrameworkHostClient/Package.swift",
            "IntegrationTests/TinyUIPrototype/Package.swift",
        ]
        let recursive = [
            "Plugins",
            "Sources",
            "Tests",
            "Examples",
            "IntegrationTests/PublicAPIClient/Tests",
            "IntegrationTests/GraphicsPreviewClient/Tests",
            "IntegrationTests/FrameworkHostClient/Tests",
            "IntegrationTests/TinyUIPrototype/Tests",
        ]
        let base =
            mode == "format"
            ? ["format", "--configuration", ".swift-format", "--in-place"]
            : ["lint", "--configuration", ".swift-format", "--strict"]
        for file in files {
            try runSwiftFormat(base + [file])
        }
        var recursiveArgs = base
        if mode == "format" {
            recursiveArgs += ["--parallel", "--recursive"]
        } else {
            recursiveArgs += ["--parallel", "--recursive"]
        }
        try runSwiftFormat(recursiveArgs + recursive)
    }

    public func runSwiftFormat(_ arguments: [String]) throws {
        if let override = context.runner.environment["SWIFT_FORMAT_BIN"], !override.isEmpty {
            try context.runner.run(override, arguments, workingDirectory: context.repository.root)
            return
        }
        if context.runner.canFind("swift-format") {
            try context.runner.run(
                "swift-format", arguments, workingDirectory: context.repository.root)
            return
        }
        try context.runner.run(
            "swift", ["format"] + arguments, workingDirectory: context.repository.root)
    }

    public func runSwiftLint() throws {
        let args = [
            "lint", "--strict", "--no-cache", "--force-exclude", "--config", ".swiftlint.yml",
        ]
        if let override = context.runner.environment["SWIFTLINT_BIN"], !override.isEmpty {
            try context.runner.run(override, args, workingDirectory: context.repository.root)
        } else {
            try context.runner.run("swiftlint", args, workingDirectory: context.repository.root)
        }
    }
}

public struct VerificationChecks {
    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    public func verifyTargetImports() throws {
        let rules: [(String, String, [String])] = [
            (
                "WaylandRaw", "Sources/WaylandRaw",
                [
                    "WaylandClient", "WaylandKeyboard", "WaylandCursor", "WaylandGraphicsCore",
                    "WaylandGraphicsPreview",
                ]
            ),
            ("WaylandKeyboard", "Sources/WaylandKeyboard", ["WaylandClient"]),
            ("WaylandCursor", "Sources/WaylandCursor", ["WaylandClient"]),
            ("WaylandGraphicsCore", "Sources/WaylandGraphicsPreview", ["WaylandClient"]),
        ]
        var failures: [String] = []
        for (label, path, modules) in rules {
            let root = context.repository.url(path)
            guard context.fileSystem.exists(root) else {
                failures.append("Missing source path for \(label): \(path)")
                continue
            }
            let files = try context.fileSystem.walk(root, includingDirectories: false)
            for file in files where file.pathExtension == "swift" {
                let text = try context.fileSystem.readText(file)
                for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false)
                    .enumerated()
                {
                    for module in modules
                    where line.range(
                        of: #"^\s*import\s+\#(module)\b"#,
                        options: .regularExpression) != nil
                    {
                        let location = "\(context.repository.relativePath(file)):\(index + 1)"
                        failures.append("\(location): \(label) must not import \(module)")
                    }
                }
            }
        }
        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
        context.diagnostics.success("target import boundaries are valid")
    }

    public func verifyUnsafeAllowlist() throws {
        let allowlistURL = context.repository.url("safety/unsafe-token-allowlist.tsv")
        let allowlist = try UnsafeAllowlist.parse(context.fileSystem.readText(allowlistURL))
        let regex = try NSRegularExpression(pattern: unsafeTokenPattern)
        var failures: [String] = []
        let roots = ["Plugins", "Sources", "Tests", "Package.swift"].map { path in
            context.repository.url(path)
        }
        for root in roots {
            let files: [URL]
            if context.fileSystem.isDirectory(root) {
                files = try context.fileSystem.walk(root, includingDirectories: false)
            } else if context.fileSystem.exists(root) {
                files = [root]
            } else {
                files = []
            }
            for file in files
            where file.pathExtension == "swift" || file.lastPathComponent == "Package.swift" {
                let text = try context.fileSystem.readText(file)
                let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(
                    String.init)
                for (index, line) in lines.enumerated() {
                    let searchableLine = removingSwiftStringLiterals(from: line)
                    let nsRange = NSRange(
                        searchableLine.startIndex..<searchableLine.endIndex, in: searchableLine)
                    for match in regex.matches(in: searchableLine, range: nsRange) {
                        guard let range = Range(match.range, in: searchableLine) else { continue }
                        let token = String(searchableLine[range])
                        let relative = context.repository.relativePath(file)
                        guard allowlist.allows(path: relative, token: token) else {
                            failures.append(
                                "\(relative):\(index + 1): unsafe token \(token) is not allowlisted"
                            )
                            continue
                        }
                        if token.hasPrefix("@unchecked"),
                            !hasSafetyComment(lines: lines, lineIndex: index)
                        {
                            failures.append(
                                "\(relative):\(index + 1): @unchecked Sendable allowlist entry "
                                    + "requires a nearby SAFETY comment"
                            )
                        }
                    }
                }
            }
        }
        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
        context.diagnostics.success("unsafe token allowlist is valid")
    }

    public func verifyShims() throws {
        let required = [
            "Sources/CWaylandProtocols/include/swift-wayland-shims.h": [
                "swl_display_get_registry", "swl_display_sync", "swl_registry_bind_wl_compositor",
                "swl_registry_bind_wl_shm", "swl_pointer_set_cursor", "swl_proxy_get_version",
            ],
            "Sources/CWaylandRuntimeShims/include/swift-wayland-runtime-shims.h": [
                "swl_eventfd", "swl_memfd_create", "swl_pipe_cloexec", "swl_write_no_sigpipe",
            ],
            "Sources/CWaylandCursorShims/include/swift-wayland-cursor-shims.h": [
                "swl_cursor_theme_load", "swl_cursor_theme_destroy", "swl_cursor_image_get_buffer",
            ],
        ]
        var failures: [String] = []
        for (headerPath, symbols) in required {
            let header = context.repository.url(headerPath)
            guard context.fileSystem.exists(header) else {
                failures.append("Missing shim header: \(headerPath)")
                continue
            }
            let text = try context.fileSystem.readText(header)
            for symbol in symbols where !text.contains(symbol) {
                failures.append("Missing shim declaration: \(symbol)")
            }
        }
        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
        context.diagnostics.success("shim declarations are valid")
    }

    public func verifyReleaseShimSymbols() throws {
        try context.swift.runSwift(
            ["build", "--disable-index-store", "-c", "release", "--target", "CWaylandProtocols"],
            repository: context.repository)
        try context.swift.runSwift(
            ["build", "--disable-index-store", "-c", "release", "--target", "CGBMShims"],
            repository: context.repository)
        _ = try context.runner.executableURL(for: "nm")
        let buildRoot = context.swift.swiftPMBuildRoot(repository: context.repository)
        let objects = try context.fileSystem.walk(
            buildRoot, includingDirectories: false
        )
        .filter { url in
            url.pathExtension == "o"
                && (url.path.contains("/release/CWaylandProtocols.build/")
                    || url.path.contains("/release/CGBMShims.build/"))
        }
        guard !objects.isEmpty else {
            throw ToolError("No release shim objects were found.", exitCode: ToolExitCode.data)
        }
        var failures: [String] = []
        for object in objects {
            let result = try context.runner.run(
                "nm", ["-g", object.path], workingDirectory: context.repository.root)
            if result.stdout.contains("swl_test_") {
                failures.append("Test shim symbol found in release object: \(object.path)")
            }
        }
        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
        context.diagnostics.success("release shim symbols are valid")
    }

    private func hasSafetyComment(lines: [String], lineIndex: Int) -> Bool {
        let start = max(0, lineIndex - 5)
        let end = min(lines.count - 1, lineIndex + 2)
        return lines[start...end].contains { $0.contains("SAFETY:") }
    }
}

private struct UnsafeAllowlist {
    var entries: [(pattern: String, token: String)]

    static func parse(_ text: String) throws -> UnsafeAllowlist {
        var entries: [(String, String)] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty, !line.hasPrefix("#") else {
                continue
            }
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(
                String.init)
            guard parts.count >= 2 else { continue }
            entries.append((parts[0], parts[1]))
        }
        return UnsafeAllowlist(entries: entries)
    }

    func allows(path: String, token: String) -> Bool {
        entries.contains { entry in
            glob(entry.pattern, matches: path) && glob(entry.token, matches: token)
        }
    }

    private func glob(_ pattern: String, matches value: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
        return value.range(of: "^\(escaped)$", options: .regularExpression) != nil
    }
}

private func removingSwiftStringLiterals(from text: String) -> String {
    var result = ""
    var inString = false
    var escaped = false
    for character in text {
        if inString {
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                inString = false
                result.append(character)
                continue
            }
            result.append(" ")
        } else {
            result.append(character)
            if character == "\"" {
                inString = true
            }
        }
    }
    return result
}

public struct PublicAPIAuditor {
    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    public func dump() throws -> String {
        var output = """
            # SwiftWayland Public API Report

            Generated from tracked Swift sources.

            ## Products

            """
        let package = try context.swift.runSwift(
            ["package", "describe", "--type", "json"], repository: context.repository)
        if let data = package.stdout.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let products = object["products"] as? [[String: Any]]
        {
            for product in products {
                if let name = product["name"] as? String {
                    output += "- \(name)\n"
                }
            }
        }
        output += "\n"
        output += try declarationsSection(
            title: "WaylandClient Public Declarations", rootPath: "Sources/WaylandClient")
        output += try declarationsSection(
            title: "WaylandGraphicsPreview Public Declarations",
            rootPath: "Sources/WaylandGraphicsPreviewAPI")
        output += try nonProductDeclarations()
        return output
    }

    public func verify(update: Bool) throws {
        let baseline = context.repository.url("docs/public-api-baseline.md")
        let report = try dump()
        let extracted = extractBaseline(from: report)
        let baselineText = """
            # SwiftWayland Public API Baseline

            This baseline records the public declarations exported by vended library
            products. Preview products are included so source-breaking preview API drift is
            visible and reviewed.

            Run `swift run swl api verify --update` only after reviewing and updating
            `docs/public-api-audit.md` for the API contract change.

            \(extracted)
            """
        if update {
            try context.fileSystem.writeText(baselineText, to: baseline)
            return
        }
        guard context.fileSystem.exists(baseline) else {
            throw ToolError(
                "Missing public API baseline: docs/public-api-baseline.md",
                exitCode: ToolExitCode.data)
        }
        let current = try context.fileSystem.readText(baseline)
        guard current == baselineText else {
            throw ToolError(
                "SwiftWayland public API changed; review and update docs/public-api-baseline.md",
                exitCode: ToolExitCode.data)
        }
        context.diagnostics.success("public API baseline is current")
    }

    private func declarationsSection(title: String, rootPath: String) throws -> String {
        var output = "## \(title)\n\n"
        let files = try context.fileSystem.walk(
            context.repository.url(rootPath), includingDirectories: false
        )
        .filter { $0.pathExtension == "swift" }
        for file in files {
            let declarations = try publicDeclarations(in: file)
            guard !declarations.isEmpty else { continue }
            output += "### `\(context.repository.relativePath(file))`\n\n"
            for declaration in declarations {
                output += "- L\(declaration.line): `\(declaration.text)`\n"
            }
            output += "\n"
        }
        return output
    }

    private func nonProductDeclarations() throws -> String {
        var output = "## Non-Product Target Public Declarations\n\n"
        output += "These declarations are not part of a vended library product "
        output += "unless the package manifest changes.\n\n"
        let excluded = ["Sources/WaylandClient/", "Sources/WaylandGraphicsPreviewAPI/"]
        let files = try context.fileSystem.walk(
            context.repository.url("Sources"), includingDirectories: false
        )
        .filter { $0.pathExtension == "swift" }
        .filter { file in
            let relative = context.repository.relativePath(file)
            return !excluded.contains { relative.hasPrefix($0) }
        }
        for file in files {
            let declarations = try publicDeclarations(in: file)
            guard !declarations.isEmpty else { continue }
            output += "### `\(context.repository.relativePath(file))`\n\n"
            for declaration in declarations {
                output += "- L\(declaration.line): `\(declaration.text)`\n"
            }
            output += "\n"
        }
        return output
    }

    private func publicDeclarations(in file: URL) throws -> [(line: Int, text: String)] {
        let lines = try context.fileSystem.readText(file).split(
            separator: "\n", omittingEmptySubsequences: false
        ).map(String.init)
        var result: [(Int, String)] = []
        var enumDepth = 0
        var inPublicEnum = false
        var enumSeenBody = false

        for (index, line) in lines.enumerated() {
            if line.range(
                of: #"^\s*([A-Za-z_][A-Za-z0-9_]*\s+)*public\s+"#, options: .regularExpression)
                != nil
            {
                result.append((index + 1, line))
            }

            let startsPublicEnum =
                line.range(
                    of: #"^\s*([A-Za-z_][A-Za-z0-9_]*\s+)*public\s+(indirect\s+)?enum\s+"#,
                    options: .regularExpression) != nil
            if startsPublicEnum {
                inPublicEnum = true
                enumDepth = 0
                enumSeenBody = false
            } else if inPublicEnum,
                enumSeenBody,
                enumDepth == 1,
                line.range(of: #"^\s*case\s+"#, options: .regularExpression) != nil
            {
                result.append((index + 1, line))
            }

            if inPublicEnum {
                for character in line {
                    if character == "{" {
                        enumDepth += 1
                        enumSeenBody = true
                    } else if character == "}" {
                        enumDepth -= 1
                    }
                }
                if enumSeenBody, enumDepth <= 0 {
                    inPublicEnum = false
                }
            }
        }
        return result
    }

    private func extractBaseline(from report: String) -> String {
        let lines = report.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var output: [String] = []
        var include = false
        for line in lines {
            if line == "## WaylandClient Public Declarations"
                || line == "## WaylandGraphicsPreview Public Declarations"
            {
                include = true
            } else if line == "## Non-Product Target Public Declarations" {
                include = false
            }
            if include {
                output.append(line)
            }
        }
        return output.joined(separator: "\n")
    }
}

public struct HeadlessWestonRunner {
    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    public func run(command: [String], timeoutSeconds: TimeInterval = 600) throws {
        guard command.isEmpty == false else {
            throw ToolError("headless smoke requires a child command", exitCode: ToolExitCode.usage)
        }
        _ = try context.runner.executableURL(for: "weston")
        let runtime = try context.fileSystem.createTemporaryDirectory(
            prefix: "swiftwayland-runtime")
        defer { try? context.fileSystem.removeItem(runtime) }
        let config = runtime.appendingPathComponent("config")
        try context.fileSystem.createDirectory(config)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: runtime.path)

        let socket = "swiftwayland-\(UUID().uuidString)"
        let westonLog = runtime.appendingPathComponent("weston.log")
        let westonProcessLog = runtime.appendingPathComponent("weston-process.log")
        let childLog = runtime.appendingPathComponent("child.log")
        let weston = Process()
        weston.executableURL = try context.runner.executableURL(for: "weston")
        weston.arguments = [
            "--backend=headless-backend.so",
            "--socket=\(socket)",
            "--idle-time=0",
            "--log=\(westonLog.path)",
        ]
        var env = context.runner.environment
        env["XDG_RUNTIME_DIR"] = runtime.path
        env["XDG_CONFIG_HOME"] = config.path
        env["WAYLAND_DISPLAY"] = socket
        env.removeValue(forKey: "WAYLAND_SOCKET")
        weston.environment = env
        let westonOutput = Pipe()
        let westonOutputBuffer = HeadlessOutputBuffer()
        weston.standardOutput = westonOutput
        weston.standardError = westonOutput
        westonOutput.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                westonOutputBuffer.append(data)
            }
        }
        defer {
            westonOutput.fileHandleForReading.readabilityHandler = nil
        }
        try weston.run()

        do {
            try waitForSocket(runtime.appendingPathComponent(socket), process: weston)
            try runChild(
                command: command,
                environment: env,
                timeoutSeconds: timeoutSeconds,
                logURL: childLog)
            stopProcess(weston, killAfter: 5)
        } catch {
            stopProcess(weston, killAfter: 5)
            westonOutputBuffer.append(westonOutput.fileHandleForReading.readDataToEndOfFile())
            try? context.fileSystem.writeData(westonOutputBuffer.data, to: westonProcessLog)
            printFailureLog(westonLog, label: "weston.log")
            printFailureLog(westonProcessLog, label: "weston process output")
            printFailureLog(childLog, label: "headless child output")
            throw error
        }
    }

    private func waitForSocket(_ socket: URL, process: Process) throws {
        for _ in 0..<100 {
            if FileManager.default.fileExists(atPath: socket.path) {
                return
            }
            if !process.isRunning {
                throw ToolError(
                    "weston exited before creating \(socket.path)", exitCode: ToolExitCode.process)
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw ToolError("weston did not create \(socket.path)", exitCode: ToolExitCode.process)
    }

    private func runChild(
        command: [String],
        environment: [String: String],
        timeoutSeconds: TimeInterval,
        logURL: URL
    ) throws {
        let process = Process()
        process.executableURL = try context.runner.executableURL(for: command[0])
        process.arguments = Array(command.dropFirst())
        process.environment = environment
        process.currentDirectoryURL = context.repository.root
        let output = Pipe()
        let outputBuffer = HeadlessOutputBuffer()
        process.standardOutput = output
        process.standardError = output
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                outputBuffer.append(data)
            }
        }
        defer {
            output.fileHandleForReading.readabilityHandler = nil
        }
        try process.run()
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        if process.isRunning {
            stopProcess(process, killAfter: 5)
            outputBuffer.append(output.fileHandleForReading.readDataToEndOfFile())
            try? context.fileSystem.writeData(outputBuffer.data, to: logURL)
            throw ToolError(
                "headless command timed out: \(command.joined(separator: " "))",
                exitCode: process.terminationStatus == 0
                    ? ToolExitCode.process : process.terminationStatus)
        }
        outputBuffer.append(output.fileHandleForReading.readDataToEndOfFile())
        try? context.fileSystem.writeData(outputBuffer.data, to: logURL)
        guard process.terminationStatus == 0 else {
            let commandText = command.joined(separator: " ")
            let message =
                "headless command failed with exit code "
                + "\(process.terminationStatus): \(commandText)"
            throw ToolError(
                message,
                exitCode: process.terminationStatus
            )
        }
    }

    private func stopProcess(_ process: Process, killAfter: TimeInterval) {
        guard process.isRunning else { return }
        process.terminate()
        guard !waitForExit(process, timeoutSeconds: killAfter) else { return }
        #if os(Linux)
            kill(process.processIdentifier, SIGKILL)
        #else
            process.terminate()
        #endif
        process.waitUntilExit()
    }

    private func waitForExit(_ process: Process, timeoutSeconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        return !process.isRunning
    }

    private func printFailureLog(_ url: URL, label: String) {
        guard let text = try? context.fileSystem.readText(url), !text.isEmpty else { return }
        context.diagnostics.error("----- \(label) -----\n\(text)\n---------------------")
    }
}

// SAFETY: storage is private and every read/write is serialized by lock.
private final class HeadlessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.withLock { storage }
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.withLock {
            storage.append(data)
        }
    }
}

// swiftlint:enable file_length function_body_length
