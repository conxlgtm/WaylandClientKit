import Foundation

public struct ExampleBuilder {
    public static let targets = [
        "ClientSideResizeChrome",
        "CompositorSessionSmoke",
        "CursorAnimationSmoke",
        "CursorPolicySmoke",
        "CustomCursorSmoke",
        "DamageRegionSmoke",
        "DataTransferSmoke",
        "FrameworkHostSmoke",
        "GPUPreviewSmokeClient",
        "GraphicsPreviewColorMetadataSmoke",
        "GraphicsPreviewExternalBufferMaintainerSmoke",
        "GraphicsPreviewExternalBufferSmoke",
        "GraphicsPreviewManagedGPUClear",
        "IdleInhibitSmoke",
        "ColorManagementSmoke",
        "OutputTopologySmoke",
        "PointerCaptureSmoke",
        "PointerWarpSmoke",
        "PresentationFeedbackAnimation",
        "SerialActionsProbe",
        "SessionStateSmoke",
        "SubsurfaceSmoke",
        "SurfaceRegionSmoke",
        "TabletInputSmoke",
        "WaylandClientKitDemo",
        "SystemBellSmoke",
        "TextInputSmoke",
        "TwoWindowFrameworkHost",
        "TwoWindowOrderStress",
        "WindowIconSmoke",
        "XDGActivationSmoke",
    ]

    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    public func buildAll(configurations: [String] = ["debug", "release"]) throws {
        try verifyTargetChecklistMatchesPackage()
        try verifyPublicExampleImportBoundaries()
        context.diagnostics.info(
            "example live execution is skipped by this build gate; examples are build-checked only")
        for configuration in configurations {
            for target in Self.targets {
                try context.swift.runSwift(
                    [
                        "build",
                        "--disable-index-store",
                        "-c",
                        configuration,
                        "--target",
                        target,
                    ],
                    repository: context.repository)
            }
        }
        context.diagnostics.success(
            "example targets build in \(configurations.joined(separator: "/"))")
    }

    private func verifyPublicExampleImportBoundaries() throws {
        // This target is a maintainer evidence probe that manufactures a dmabuf
        // with package-internal GBM/EGL helpers; user-facing examples must stay
        // on public products.
        let allowlistedInternalImportTargets: Set<String> = [
            "GraphicsPreviewExternalBufferMaintainerSmoke"
        ]
        let forbiddenModules = [
            "WaylandGraphicsCore",
            "WaylandGPUPreview",
            "WaylandRaw",
        ]
        var failures: [String] = []
        for target in Self.targets where !allowlistedInternalImportTargets.contains(target) {
            let root = context.repository.url("Examples/\(target)")
            guard context.fileSystem.exists(root) else { continue }
            let files = try context.fileSystem.walk(root, includingDirectories: false)
            for file in files where file.pathExtension == "swift" {
                let text = try context.fileSystem.readText(file)
                for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false)
                    .enumerated()
                {
                    for module in forbiddenModules
                    where line.range(
                        of: #"^\s*import\s+\#(module)\b"#,
                        options: .regularExpression) != nil
                    {
                        let location = "\(context.repository.relativePath(file)):\(index + 1)"
                        failures.append("\(location): public examples must not import \(module)")
                    }
                }
            }
        }

        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
    }

    public static func packageExampleTargets(
        repository: Repository,
        fileSystem: FileSystem = LocalFileSystem()
    ) throws -> Set<String> {
        let packageText = try fileSystem.readText(repository.url("Package.swift"))
        let executableTargetPattern =
            #"\.executableTarget\(\s*(?:name:\s*"([^"]+)",\s*)?"#
            + #"[^)]*path:\s*"Examples/([^"]+)""#
        let regex = try NSRegularExpression(
            pattern: executableTargetPattern,
            options: [.dotMatchesLineSeparators]
        )
        let range = NSRange(packageText.startIndex..<packageText.endIndex, in: packageText)
        return Set(
            regex.matches(in: packageText, range: range).compactMap { match in
                if let nameRange = Range(match.range(at: 1), in: packageText) {
                    return String(packageText[nameRange])
                }
                guard let pathRange = Range(match.range(at: 2), in: packageText) else {
                    return nil
                }
                return URL(fileURLWithPath: String(packageText[pathRange])).lastPathComponent
            })
    }

    private func verifyTargetChecklistMatchesPackage() throws {
        let packageTargets = try Self.packageExampleTargets(
            repository: context.repository,
            fileSystem: context.fileSystem)
        let checklistTargets = Set(Self.targets)
        let missing = packageTargets.subtracting(checklistTargets).sorted()
        let extra = checklistTargets.subtracting(packageTargets).sorted()
        guard missing.isEmpty, extra.isEmpty else {
            var failures: [String] = []
            if !missing.isEmpty {
                let missingTargets = missing.joined(separator: ", ")
                failures.append(
                    "Example targets missing from build checklist: \(missingTargets)"
                )
            }
            if !extra.isEmpty {
                let extraTargets = extra.joined(separator: ", ")
                failures.append(
                    "Example build checklist targets missing from Package.swift: "
                        + "\(extraTargets)")
            }
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
    }
}
