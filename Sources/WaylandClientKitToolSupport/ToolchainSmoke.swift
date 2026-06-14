import Foundation

public struct ToolchainSmoke {
    public static let stableBaseline = "6.3.2"

    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    public func report(runSwiftBuildPreview: Bool = true) throws -> String {
        var lines: [String] = []
        lines.append("WaylandClientKit toolchain smoke")
        lines.append(
            "Swift wrapper version: \(try context.swift.version(repository: context.repository))")
        lines.append(
            "Package.swift tools version: "
                + (try Self.packageToolsVersion(
                    repository: context.repository,
                    fileSystem: context.fileSystem)))
        lines.append("Current stable baseline: Swift \(Self.stableBaseline)")
        lines.append("Swift 6.4.x snapshot: optional allowed-failure")
        lines.append(
            "SWIFT_NEXT_BIN: "
                + (try swiftNextStatus(environment: context.runner.environment)))
        if runSwiftBuildPreview {
            lines.append("Swift Build preview: \(try swiftBuildPreviewStatus())")
        } else {
            lines.append("Swift Build preview: skipped")
        }
        return lines.joined(separator: "\n")
    }

    public static func packageToolsVersion(repository: Repository, fileSystem: FileSystem) throws
        -> String
    {
        let manifest = try fileSystem.readText(repository.url("Package.swift"))
        guard let firstLine = manifest.split(separator: "\n").first else {
            throw ToolError("Package.swift is empty", exitCode: ToolExitCode.data)
        }
        let prefix = "// swift-tools-version:"
        let line = firstLine.trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix(prefix) else {
            throw ToolError(
                "Package.swift is missing swift-tools-version", exitCode: ToolExitCode.data)
        }
        return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
    }

    public static func classifySwiftBuildPreview(result: ProcessResult) -> String {
        if result.exitCode == 0 {
            return "available"
        }
        let output = "\(result.stdout)\n\(result.stderr)".lowercased()
        if output.contains("unknown option '--build-system'")
            || output.contains("unknown option")
                && output.contains("build-system")
        {
            return "unsupported"
        }
        if output.contains("toolchain")
            || output.contains("swiftly")
        {
            return "failed-toolchain-layout"
        }
        return "failed-package(exit \(result.exitCode))"
    }

    private func swiftNextStatus(environment: [String: String]) throws -> String {
        guard let swiftNext = environment["SWIFT_NEXT_BIN"], !swiftNext.isEmpty else {
            return "not set"
        }
        let result: ProcessResult
        do {
            result = try context.runner.run(swiftNext, ["--version"], requireSuccess: false)
        } catch {
            return "set but not runnable (\(swiftNext))"
        }
        let version =
            result.stdout.split(separator: "\n").first
            ?? result.stderr.split(separator: "\n").first
        guard result.exitCode == 0, let version else {
            return "set but not runnable (\(swiftNext))"
        }
        return "\(swiftNext) (\(version))"
    }

    private func swiftBuildPreviewStatus() throws -> String {
        let result = try context.swift.runSwift(
            [
                "build", "--build-system", "swiftbuild", "--disable-index-store",
                "--target", "WaylandClientKitToolSupport",
            ],
            repository: context.repository,
            requireSuccess: false
        )
        return Self.classifySwiftBuildPreview(result: result)
    }
}
