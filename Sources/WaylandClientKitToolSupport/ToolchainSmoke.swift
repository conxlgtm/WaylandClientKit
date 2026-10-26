import Foundation

public struct ToolchainSmoke {
    public static let stableBaseline = "6.4.0"

    public let context: ToolContext

    public init(context: ToolContext) {
        self.context = context
    }

    public func report() async throws -> String {
        let version = try await context.swift.version(repository: context.repository)
        try Self.requireMinimumVersion(version)
        try await context.swift.runSwift(
            ["build", "--disable-index-store", "--target", "WaylandClientKitToolSupport"],
            repository: context.repository)
        return [
            "WaylandClientKit toolchain smoke",
            "Swift wrapper version: \(version)",
            "Package.swift tools version: "
                + (try Self.packageToolsVersion(
                    repository: context.repository, fileSystem: context.fileSystem)),
            "Required baseline: Swift \(Self.stableBaseline)",
            "Default Swift Build backend: build passed",
        ].joined(separator: "\n")
    }

    public static func requireMinimumVersion(_ output: String) throws {
        let regex = try NSRegularExpression(pattern: #"Swift version (\d+)\.(\d+)(?:\.(\d+))?"#)
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, range: range),
            let majorRange = Range(match.range(at: 1), in: output),
            let minorRange = Range(match.range(at: 2), in: output),
            let major = Int(output[majorRange]), let minor = Int(output[minorRange])
        else {
            throw ToolError("Cannot identify Swift version: \(output)", exitCode: ToolExitCode.data)
        }
        guard major > 6 || (major == 6 && minor >= 4) else {
            throw ToolError(
                "Swift \(Self.stableBaseline) or newer is required: \(output)",
                exitCode: ToolExitCode.environment)
        }
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
}
