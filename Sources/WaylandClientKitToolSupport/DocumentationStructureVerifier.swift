import Foundation

public struct DocumentationStructureVerifier {
    public struct RequiredPhrase: Sendable {
        public let path: String
        public let phrase: String
        public let description: String

        public init(path: String, phrase: String, description: String) {
            self.path = path
            self.phrase = phrase
            self.description = description
        }
    }

    public static let requiredFiles = [
        "README.md",
        "CONTRIBUTING.md",
        "docs/compatibility-policy.md",
        "docs/compositor-matrix.md",
        "docs/documentation-map.md",
        "docs/documentation-symbol-coverage.json",
        "docs/generation.md",
        "docs/getting-started.md",
        "docs/live-wayland-testing.md",
        "docs/public-api-audit.md",
        "docs/public-api-baseline.md",
        "docs/release.md",
        "docs/session-readiness.md",
        "docs/strict-memory-safety-audit.md",
        "docs/tooling.md",
        "docs/which-api-should-i-use.md",
        "Sources/WaylandClient/WaylandClient.docc/ActivationAndFocusHandoff.md",
        "Sources/WaylandClient/WaylandClient.docc/CapabilitiesAndOptionalProtocols.md",
        "Sources/WaylandClient/WaylandClient.docc/CursorShapeAndThemeFallback.md",
        "Sources/WaylandClient/WaylandClient.docc/DataTransferAndDragIcons.md",
        "Sources/WaylandClient/WaylandClient.docc/DesktopIntegration.md",
        "Sources/WaylandClient/WaylandClient.docc/DiagnosticsAndDisplayFailures.md",
        "Sources/WaylandClient/WaylandClient.docc/DisplayLifecycle.md",
        "Sources/WaylandClient/WaylandClient.docc/EventStreamsAndOverflow.md",
        "Sources/WaylandClient/WaylandClient.docc/InputAndTextInput.md",
        "Sources/WaylandClient/WaylandClient.docc/PointerCapture.md",
        "Sources/WaylandClient/WaylandClient.docc/PresentationFeedbackAndFrameCallbacks.md",
        "Sources/WaylandClient/WaylandClient.docc/SessionReadiness.md",
        "Sources/WaylandClient/WaylandClient.docc/Subsurfaces.md",
        "Sources/WaylandClient/WaylandClient.docc/SurfaceRegionsAndDamage.md",
        "Sources/WaylandClient/WaylandClient.docc/TextInputLifecycle.md",
        "Sources/WaylandClient/WaylandClient.docc/WaylandClient.md",
        "Sources/WaylandClient/WaylandClient.docc/WindowDrawing.md",
        "Sources/WaylandGraphicsPreview/WaylandGraphicsPreview.docc/FrameLeases.md",
        "Sources/WaylandGraphicsPreview/WaylandGraphicsPreview.docc/GraphicsPreviewOverview.md",
        "Sources/WaylandGraphicsPreview/WaylandGraphicsPreview.docc/GraphicsRuntimePath.md",
        "Sources/WaylandGraphicsPreview/WaylandGraphicsPreview.docc/ManagedGPUPreview.md",
        "Sources/WaylandGraphicsPreview/WaylandGraphicsPreview.docc/ManagedGraphicsBacking.md",
        "Sources/WaylandGraphicsPreview/WaylandGraphicsPreview.docc/SoftwareFallback.md",
        "Sources/WaylandGraphicsPreview/WaylandGraphicsPreview.docc/WaylandGraphicsPreview.md",
    ]

    public static let requiredPhrases = [
        RequiredPhrase(
            path: "README.md",
            phrase: "docs/getting-started.md",
            description: "README links to getting started"),
        RequiredPhrase(
            path: "README.md",
            phrase: "docs/which-api-should-i-use.md",
            description: "README links to API chooser"),
        RequiredPhrase(
            path: "docs/session-readiness.md",
            phrase: "XDG_STATE_HOME",
            description: "session readiness documents app-owned state root"),
        RequiredPhrase(
            path: "docs/session-readiness.md",
            phrase: "Activation tokens are compositor-mediated focus or raise requests",
            description: "session readiness separates activation from restoration"),
        RequiredPhrase(
            path: "Sources/WaylandGraphicsPreview/WaylandGraphicsPreview.docc/"
                + "WaylandGraphicsPreview.md",
            phrase: "source-breaking",
            description: "graphics preview root states preview/source-breaking policy"),
        RequiredPhrase(
            path: "Sources/WaylandGraphicsPreview/WaylandGraphicsPreview.docc/"
                + "WaylandGraphicsPreview.md",
            phrase: "raw GPU",
            description: "graphics preview root states raw GPU handles are not public"),
        RequiredPhrase(
            path: "Sources/WaylandClient/WaylandClient.docc/TextInputLifecycle.md",
            phrase: "disable() finalizes",
            description: "text input docs mention disable semantics"),
    ]

    public let repository: Repository
    public let fileSystem: FileSystem

    public init(repository: Repository, fileSystem: FileSystem = LocalFileSystem()) {
        self.repository = repository
        self.fileSystem = fileSystem
    }

    public func verify() throws {
        var failures: [String] = []
        for path in Self.requiredFiles where !fileSystem.exists(repository.url(path)) {
            failures.append("Missing required documentation file: \(path)")
        }

        for requirement in Self.requiredPhrases {
            let url = repository.url(requirement.path)
            guard fileSystem.exists(url) else {
                continue
            }
            let text = try fileSystem.readText(url)
            if !text.contains(requirement.phrase) {
                failures.append(
                    "\(requirement.path): missing required documentation text for "
                        + "\(requirement.description): \(requirement.phrase)"
                )
            }
        }

        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
    }
}
