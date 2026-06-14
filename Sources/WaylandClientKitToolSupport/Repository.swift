import Foundation

public struct Repository: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root.standardizedFileURL
    }

    public static func detect(
        from currentDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileSystem: FileSystem = LocalFileSystem()
    ) throws -> Repository {
        if let override = environment["WAYLAND_CLIENT_KIT_ROOT"], !override.isEmpty {
            let root = URL(fileURLWithPath: override).standardizedFileURL
            try validateRoot(root, fileSystem: fileSystem)
            return Repository(root: root)
        }

        var candidate = currentDirectory.standardizedFileURL
        while true {
            if isRoot(candidate, fileSystem: fileSystem) {
                return Repository(root: candidate)
            }

            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path {
                throw ToolError(
                    "could not locate WaylandClientKit repository root from "
                        + currentDirectory.path,
                    exitCode: ToolExitCode.environment
                )
            }
            candidate = parent
        }
    }

    public func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }

    public func relativePath(_ url: URL) -> String {
        let rootPath = root.path
        let path = url.standardizedFileURL.path
        if path == rootPath {
            return "."
        }
        if path.hasPrefix(rootPath + "/") {
            return String(path.dropFirst(rootPath.count + 1))
        }
        return path
    }

    public func contains(_ url: URL) -> Bool {
        let rootPath = root.path
        let path = url.standardizedFileURL.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private static func validateRoot(_ root: URL, fileSystem: FileSystem) throws {
        guard isRoot(root, fileSystem: fileSystem) else {
            throw ToolError(
                "WAYLAND_CLIENT_KIT_ROOT does not point at a WaylandClientKit repository: "
                    + root.path,
                exitCode: ToolExitCode.environment
            )
        }
    }

    private static func isRoot(_ url: URL, fileSystem: FileSystem) -> Bool {
        fileSystem.exists(url.appendingPathComponent("Package.swift"))
            && fileSystem.exists(url.appendingPathComponent("Sources"))
            && fileSystem.exists(url.appendingPathComponent("protocols"))
    }
}
