import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

// This file coordinates repository-wide checks. Each checker is still typed and testable.
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

private func symbolList(_ symbols: String) -> [String] {
    symbols.split(whereSeparator: \.isNewline)
        .map { String($0).trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
}

private let protocolShimSymbols = symbolList(
    """
    swl_display_get_registry
    swl_display_sync
    swl_display_create_event_queue
    swl_event_queue_destroy
    swl_display_create_wrapper
    swl_display_wrapper_set_queue
    swl_display_wrapper_destroy
    swl_display_dispatch_event_queue_pending
    swl_display_prepare_read_event_queue
    swl_display_get_protocol_error_details
    swl_registry_bind_wl_compositor
    swl_registry_bind_wl_shm
    swl_registry_bind_xdg_wm_base
    swl_registry_bind_zxdg_decoration_manager_v1
    swl_registry_bind_zxdg_output_manager_v1
    swl_registry_bind_wp_viewporter
    swl_registry_bind_wp_presentation
    swl_registry_bind_wp_fractional_scale_manager_v1
    swl_registry_bind_wl_seat
    swl_registry_bind_zwp_linux_dmabuf_v1
    swl_registry_bind_zwp_primary_selection_device_manager_v1
    swl_registry_add_listener
    swl_callback_add_listener
    swl_buffer_add_listener
    swl_surface_add_listener
    swl_xdg_wm_base_add_listener
    swl_xdg_surface_add_listener
    swl_xdg_toplevel_add_listener
    swl_zxdg_toplevel_decoration_v1_add_listener
    swl_wp_fractional_scale_v1_add_listener
    swl_seat_add_listener
    swl_pointer_add_listener
    swl_keyboard_add_listener
    swl_touch_add_listener
    swl_primary_selection_offer_add_listener
    swl_primary_selection_source_add_listener
    swl_primary_selection_device_add_listener
    swl_pointer_set_cursor
    swl_primary_selection_device_manager_create_source
    swl_primary_selection_device_manager_get_device
    swl_primary_selection_source_offer
    swl_primary_selection_offer_receive
    swl_primary_selection_device_set_selection
    swl_primary_selection_offer_destroy
    swl_primary_selection_source_destroy
    swl_primary_selection_device_destroy
    swl_primary_selection_device_manager_destroy
    swl_shm_format_xrgb8888
    swl_shm_format_argb8888
    swl_proxy_get_version
    swl_proxy_get_id
    swl_proxy_get_queue_raw
    swl_zxdg_decoration_manager_v1_get_toplevel_decoration
    swl_zxdg_output_manager_v1_get_xdg_output
    swl_zxdg_toplevel_decoration_v1_set_mode
    swl_zxdg_toplevel_decoration_v1_unset_mode
    swl_zxdg_toplevel_decoration_v1_mode_client_side
    swl_zxdg_toplevel_decoration_v1_mode_server_side
    swl_zxdg_toplevel_decoration_v1_destroy
    swl_zxdg_decoration_manager_v1_destroy
    swl_zxdg_output_v1_destroy
    swl_zxdg_output_manager_v1_destroy
    swl_zxdg_output_v1_add_listener
    swl_wp_viewporter_get_viewport
    swl_wp_viewport_set_destination
    swl_wp_viewport_destroy
    swl_wp_viewporter_destroy
    swl_wp_presentation_feedback
    swl_wp_presentation_destroy
    swl_wp_presentation_feedback_destroy
    swl_wp_presentation_add_listener
    swl_wp_presentation_feedback_add_listener
    swl_zwp_linux_dmabuf_v1_destroy
    swl_zwp_linux_dmabuf_v1_get_default_feedback
    swl_zwp_linux_dmabuf_v1_get_surface_feedback
    swl_zwp_linux_dmabuf_v1_create_params
    swl_zwp_linux_buffer_params_v1_add
    swl_zwp_linux_buffer_params_v1_create
    swl_zwp_linux_buffer_params_v1_destroy
    swl_zwp_linux_buffer_params_v1_add_listener
    swl_zwp_linux_dmabuf_feedback_v1_destroy
    swl_zwp_linux_dmabuf_feedback_v1_add_listener
    swl_wp_fractional_scale_manager_v1_get_fractional_scale
    swl_wp_fractional_scale_v1_destroy
    swl_wp_fractional_scale_manager_v1_destroy
    swl_surface_set_buffer_scale
    """
)

private let cursorShimSymbols = symbolList(
    """
    swl_cursor_theme_load
    swl_cursor_theme_destroy
    swl_cursor_theme_get_cursor
    swl_cursor_image_count
    swl_cursor_image_at
    swl_cursor_image_width
    swl_cursor_image_height
    swl_cursor_image_hotspot_x
    swl_cursor_image_hotspot_y
    swl_cursor_image_delay
    swl_cursor_image_get_buffer
    """
)

private let runtimeShimSymbols = symbolList(
    """
    swl_eventfd
    swl_efd_cloexec
    swl_efd_nonblock
    swl_memfd_create
    swl_mfd_cloexec
    swl_pipe_cloexec
    swl_write_no_sigpipe
    """
)

private struct ShimVerificationRule {
    let label: String
    let headerPath: String
    let implementationPath: String
    let symbols: [String]
}

private let shimVerificationRules = [
    ShimVerificationRule(
        label: "protocol",
        headerPath: "Sources/CWaylandProtocols/include/wayland-client-kit-shims.h",
        implementationPath: "Sources/CWaylandProtocols/shims",
        symbols: protocolShimSymbols),
    ShimVerificationRule(
        label: "runtime",
        headerPath: "Sources/CWaylandRuntimeShims/include/wayland-client-kit-runtime-shims.h",
        implementationPath: "Sources/CWaylandRuntimeShims",
        symbols: runtimeShimSymbols),
    ShimVerificationRule(
        label: "cursor",
        headerPath: "Sources/CWaylandCursorShims/include/wayland-client-kit-cursor-shims.h",
        implementationPath: "Sources/CWaylandCursorShims",
        symbols: cursorShimSymbols),
]

private let shimTestingGateHeaderPaths = [
    "Sources/CWaylandProtocols/include/wayland-client-kit-shims.h",
    "Sources/CGBMShims/include/wayland-client-kit-gbm-shims.h",
]

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
        do {
            let result = try context.runner.run(
                "swift", ["format", "--version"], requireSuccess: false)
            return result.exitCode == 0
        } catch {
            return false
        }
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
            "IntegrationTests/InvalidManagedIdentityClient/Package.swift",
            "IntegrationTests/InvalidApplicationIdentityClient/Package.swift",
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
            "IntegrationTests/InvalidManagedIdentityClient/Sources",
            "IntegrationTests/InvalidApplicationIdentityClient/Sources",
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
            "lint", "--strict", "--no-cache", "--quiet", "--force-exclude", "--config",
            ".swiftlint.yml",
        ]
        if let override = context.runner.environment["SWIFTLINT_BIN"], !override.isEmpty {
            try runStrictSwiftLint(override, args: args)
            return
        }

        let pinned = context.repository.url(".build/tools/swiftlint")
        if context.fileSystem.isExecutable(pinned) {
            try runStrictSwiftLint(pinned.path, args: args)
            return
        }

        if tools.canRunPathTool("swiftlint", probeArguments: ["version"]) {
            try runStrictSwiftLint("swiftlint", args: args)
            return
        }

        throw strictSwiftLintError()
    }

    private var tools: RepositoryNixTools {
        RepositoryNixTools(
            repository: context.repository,
            fileSystem: context.fileSystem,
            runner: context.runner,
            diagnostics: context.diagnostics
        )
    }

    private func runStrictSwiftLint(_ executable: String, args: [String]) throws {
        guard swiftLintEnforcesCustomRules(executable) else {
            throw strictSwiftLintError()
        }
        try context.runner.run(executable, args, workingDirectory: context.repository.root)
    }

    private func swiftLintEnforcesCustomRules(_ executable: String) -> Bool {
        let probe = context.repository.url(
            "Sources/.swiftlint-custom-rules-probe-\(UUID().uuidString).swift")
        do {
            try context.fileSystem.writeText(
                "func throwingProbe() throws {}\n"
                    + "func probe() { _ = try" + "? throwingProbe() }\n",
                to: probe
            )
        } catch {
            return false
        }
        defer {
            do {
                try context.fileSystem.removeItem(probe)
            } catch {
                // Cleanup best-effort only.
            }
        }

        do {
            let result = try context.runner.run(
                executable,
                [
                    "lint", "--strict", "--no-cache", "--quiet", "--force-exclude", "--config",
                    ".swiftlint.yml", probe.path,
                ],
                workingDirectory: context.repository.root,
                requireSuccess: false
            )
            let output = result.stdout + result.stderr
            return result.exitCode != 0 && output.contains("no_silent_try_optional")
        } catch {
            return false
        }
    }

    private func strictSwiftLintError() -> ToolError {
        ToolError(
            "SwiftLint with SourceKit custom_rules is required. "
                + "Run `swift run wck tools install-swiftlint --destination .build/tools`.",
            exitCode: ToolExitCode.environment
        )
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

    public func verifyToolDependencyBoundaries() throws {
        let dump = try context.swift.runSwift(
            ["package", "dump-package"], repository: context.repository
        ).stdout
        try PackageDependencyBoundaryVerifier().verify(packageDump: dump)
        context.diagnostics.success("tool dependencies are isolated")
    }

    public func verifyUnsafeAllowlist() throws {
        let allowlistURL = context.repository.url("safety/unsafe-token-allowlist.tsv")
        let allowlist = try UnsafeAllowlist.parse(context.fileSystem.readText(allowlistURL))
        let regex = try NSRegularExpression(pattern: unsafeTokenPattern)
        var failures: [String] = []
        for file in try unsafeAllowlistScanFiles() {
            let relative = context.repository.relativePath(file)
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
        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
        context.diagnostics.success("unsafe token allowlist is valid")
    }

    private func unsafeAllowlistScanFiles() throws -> [URL] {
        let roots = ["Plugins", "Sources", "Tests", "Package.swift"].map { path in
            context.repository.url(path)
        }
        var files: [URL] = []
        for root in roots {
            if context.fileSystem.isDirectory(root) {
                files.append(
                    contentsOf: try context.fileSystem.walk(
                        root,
                        includingDirectories: false))
            } else if context.fileSystem.exists(root) {
                files.append(root)
            }
        }
        return files.filter { file in
            shouldScanForUnsafeTokens(
                file: file,
                relativePath: context.repository.relativePath(file))
        }
    }

    public func verifyShims() throws {
        var failures: [String] = []
        for headerPath in shimTestingGateHeaderPaths {
            let header = context.repository.url(headerPath)
            guard context.fileSystem.exists(header) else { continue }
            let text = try context.fileSystem.readText(header)
            if text.range(
                of: #"\bNDEBUG\b|#define\s+SWL_ENABLE_TESTING\b"#,
                options: .regularExpression) != nil
            {
                failures.append(
                    "Testing shims must be gated by Package.swift, not header defaults: "
                        + headerPath
                )
            }
        }
        for rule in shimVerificationRules {
            let headerPath = context.repository.url(rule.headerPath)
            let implementationPath = context.repository.url(rule.implementationPath)
            guard context.fileSystem.exists(headerPath) else {
                failures.append("Missing \(rule.label) shim header: \(rule.headerPath)")
                continue
            }
            guard context.fileSystem.isDirectory(implementationPath) else {
                failures.append(
                    "Missing \(rule.label) shim implementation directory: "
                        + rule.implementationPath
                )
                continue
            }
            let headerText = try context.fileSystem.readText(headerPath)
            let implementationText = try shimImplementationText(
                under: implementationPath,
                relativePath: rule.implementationPath,
                failures: &failures)
            for symbol in rule.symbols {
                if !containsIdentifier(symbol, in: headerText) {
                    failures.append("Missing shim declaration: \(symbol)")
                }
                if !containsIdentifier(symbol, in: implementationText) {
                    failures.append("Missing shim implementation: \(symbol)")
                }
            }
        }
        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
        context.diagnostics.success("shim declarations and implementations are valid")
    }

    private func shimImplementationText(
        under directory: URL,
        relativePath: String,
        failures: inout [String]
    ) throws -> String {
        let files = try context.fileSystem.walk(directory, includingDirectories: false)
            .filter { $0.pathExtension == "c" }
            .sorted { $0.path < $1.path }
        if files.isEmpty {
            failures.append("Missing shim implementation sources: \(relativePath)")
        }
        return try files.map { try context.fileSystem.readText($0) }.joined(separator: "\n")
    }

    private func containsIdentifier(_ identifier: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: identifier)
        return text.range(
            of: #"(?<![A-Za-z0-9_])\#(escaped)(?![A-Za-z0-9_])"#,
            options: .regularExpression) != nil
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

    private func shouldScanForUnsafeTokens(file: URL, relativePath: String) -> Bool {
        if file.lastPathComponent == "Package.swift" {
            return true
        }
        if file.pathExtension == "swift" {
            return true
        }
        return relativePath.hasPrefix("Sources/")
            && ["c", "h"].contains(file.pathExtension)
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

    public func dump(environment: [String: String] = [:]) throws -> String {
        let verifier = DocCVerifier(
            repository: context.repository,
            buildRoot: context.swift.swiftPMBuildRoot(repository: context.repository),
            fileSystem: context.fileSystem,
            diagnostics: context.diagnostics
        )
        try verifier.removePublicProductSymbolGraphs()
        let result = try context.swift.runSwift(
            [
                "package", "dump-symbol-graph", "--minimum-access-level", "public",
                "--skip-synthesized-members",
            ],
            repository: context.repository,
            environment: environment,
            requireSuccess: false
        )
        try verifier.requirePublicProductSymbolGraphs(
            afterDump: result,
            allowingNonProductFailures: true
        )
        let report = try SemanticPublicAPIBaseline(fileSystem: context.fileSystem).render(
            symbolGraphs: verifier.publicProductSymbolGraphs()
        )
        return "# WaylandClientKit Semantic Public API Report\n\n\(report)"
    }

    public func verify(update: Bool, environment: [String: String] = [:]) throws {
        let baseline = context.repository.url("docs/public-api-baseline.md")
        let report = try dump(environment: environment)
        let symbolGraphs = try DocCVerifier(
            repository: context.repository,
            buildRoot: context.swift.swiftPMBuildRoot(repository: context.repository),
            fileSystem: context.fileSystem,
            diagnostics: context.diagnostics
        ).publicProductSymbolGraphs()
        try DocumentationSymbolCoverageVerifier(fileSystem: context.fileSystem).verify(
            symbolGraphs: symbolGraphs,
            baseline: context.repository.url("docs/documentation-symbol-coverage.json"),
            update: update
        )
        let reportBody = report.split(separator: "\n", omittingEmptySubsequences: false)
            .dropFirst(2)
            .joined(separator: "\n")
        let baselineText = """
            # WaylandClientKit Public API Baseline

            This baseline records compiler-emitted public symbols and relationships for
            vended library products. Source locations and formatting are excluded, while
            continuation-line signature changes remain visible. Preview products are
            included so source-breaking preview API drift is reviewed.

            Run `swift run wck api verify --update` only after reviewing and updating
            `docs/public-api-audit.md` for the API contract change.

            \(reportBody)
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
                "WaylandClientKit public API changed; "
                    + "review and update docs/public-api-baseline.md",
                exitCode: ToolExitCode.data)
        }
        context.diagnostics.success("public API baseline is current")
    }
}

public struct HeadlessWestonRunner {
    public static let requestProcessTimeoutEnvironmentKey =
        "WAYLAND_CLIENT_KIT_REQUEST_PROCESS_TIMEOUT_SECONDS"
    public static let defaultRequestProcessTimeoutSeconds: TimeInterval = 600

    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    public func run(command: [String], timeoutSeconds: TimeInterval? = nil) throws {
        guard command.isEmpty == false else {
            throw ToolError("headless smoke requires a child command", exitCode: ToolExitCode.usage)
        }
        let childTimeoutSeconds: TimeInterval
        if let timeoutSeconds {
            childTimeoutSeconds = timeoutSeconds
        } else {
            childTimeoutSeconds = try Self.requestProcessTimeoutSeconds(
                environment: context.runner.environment)
        }
        let childCommand = try swiftPMCommandIfNeeded(command)
        _ = try context.runner.executableURL(for: "weston")
        let runtime = try context.fileSystem.createTemporaryDirectory(
            prefix: "swlrt")
        defer { ignoreCleanupError { try context.fileSystem.removeItem(runtime) } }
        let config = runtime.appendingPathComponent("config")
        try context.fileSystem.createDirectory(config)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: runtime.path)

        let socket = "w\(UUID().uuidString.prefix(8))"
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
                command: childCommand,
                environment: env,
                timeoutSeconds: childTimeoutSeconds,
                logURL: childLog)
            stopProcess(weston, killAfter: 5)
        } catch {
            stopProcess(weston, killAfter: 5)
            westonOutputBuffer.append(westonOutput.fileHandleForReading.readDataToEndOfFile())
            writeLogData(westonOutputBuffer.data, to: westonProcessLog)
            printFailureLog(westonLog, label: "weston.log")
            printFailureLog(westonProcessLog, label: "weston process output")
            printFailureLog(childLog, label: "headless child output")
            throw error
        }
    }

    public static func requestProcessTimeoutSeconds(environment: [String: String]) throws
        -> TimeInterval
    {
        guard
            let rawValue = environment[requestProcessTimeoutEnvironmentKey]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawValue.isEmpty
        else {
            return defaultRequestProcessTimeoutSeconds
        }
        guard let value = TimeInterval(rawValue), value.isFinite, value > 0 else {
            throw ToolError(
                "invalid \(requestProcessTimeoutEnvironmentKey): expected positive seconds",
                exitCode: ToolExitCode.environment)
        }
        return value
    }

    private func swiftPMCommandIfNeeded(_ command: [String]) throws -> [String] {
        guard command.first == "wck" else {
            return command
        }
        let swift = try context.swift.swiftExecutable(environment: context.runner.environment)
        return [swift, "run", "wck"] + Array(command.dropFirst())
    }

    private func waitForSocket(_ socket: URL, process: Process) throws {
        for _ in 0..<100 {
            if Self.isUnixSocket(socket) {
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

    public static func isUnixSocket(_ url: URL) -> Bool {
        var status = stat()
        guard lstat(url.path, &status) == 0 else { return false }
        return (status.st_mode & S_IFMT) == S_IFSOCK
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
            writeLogData(outputBuffer.data, to: logURL)
            throw ToolError(
                "headless command timed out: \(command.joined(separator: " "))",
                exitCode: process.terminationStatus == 0
                    ? ToolExitCode.process : process.terminationStatus)
        }
        outputBuffer.append(output.fileHandleForReading.readDataToEndOfFile())
        writeLogData(outputBuffer.data, to: logURL)
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
        let text: String
        do {
            text = try context.fileSystem.readText(url)
        } catch {
            return
        }
        guard !text.isEmpty else { return }
        context.diagnostics.error("----- \(label) -----\n\(text)\n---------------------")
    }

    private func writeLogData(_ data: Data, to url: URL) {
        do {
            try context.fileSystem.writeData(data, to: url)
        } catch {
            // Failure logs are diagnostic only.
        }
    }

    private func ignoreCleanupError(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            // Cleanup best-effort only.
        }
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
