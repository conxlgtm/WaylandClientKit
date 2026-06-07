import Foundation

public struct ExampleBuilder {
    public static let targets = [
        "ClientSideResizeChrome",
        "CursorPolicySmoke",
        "CustomCursorSmoke",
        "DamageRegionSmoke",
        "DataTransferSmoke",
        "FrameworkHostSmoke",
        "GPUPreviewSmokeClient",
        "GraphicsPreviewManagedGPUClear",
        "IdleInhibitSmoke",
        "PointerCaptureSmoke",
        "PresentationFeedbackAnimation",
        "SerialActionsProbe",
        "SubsurfaceSmoke",
        "SurfaceRegionSmoke",
        "SwiftWaylandDemo",
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
