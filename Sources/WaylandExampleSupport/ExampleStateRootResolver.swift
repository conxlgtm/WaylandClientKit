import Foundation

public enum ExampleStateRootError: Error, Equatable, Sendable, CustomStringConvertible {
    case relativeStateRoot(argument: String, path: String)
    case missingStateRoot

    public var description: String {
        switch self {
        case .relativeStateRoot(let argument, let path):
            "\(argument) must be an absolute path: \(path)"
        case .missingStateRoot:
            "XDG_STATE_HOME and HOME are unset or invalid. Pass --state-root."
        }
    }
}

public struct ExampleStateRootResolver: Equatable, Sendable {
    public let appID: String
    public let explicitRoot: String?
    public let environment: [String: String]

    public init(
        appID resolverAppID: String,
        explicitRoot resolverExplicitRoot: String? = nil,
        environment resolverEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        appID = resolverAppID
        explicitRoot = resolverExplicitRoot
        environment = resolverEnvironment
    }

    public func stateFile(fileName: String = "session.json") throws -> URL {
        try stateRootURL()
            .appendingPathComponent(appID, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    public func stateRootURL() throws -> URL {
        if let explicitRoot, !explicitRoot.isEmpty {
            guard let url = Self.absoluteDirectoryURL(explicitRoot) else {
                throw ExampleStateRootError.relativeStateRoot(
                    argument: "--state-root",
                    path: explicitRoot
                )
            }
            return url
        }

        if let xdgStateHome = environment["XDG_STATE_HOME"],
            !xdgStateHome.isEmpty,
            let url = Self.absoluteDirectoryURL(xdgStateHome)
        {
            return url
        }

        guard let home = environment["HOME"],
            !home.isEmpty,
            let homeURL = Self.absoluteDirectoryURL(home)
        else {
            throw ExampleStateRootError.missingStateRoot
        }

        return
            homeURL
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
    }

    private static func absoluteDirectoryURL(_ path: String) -> URL? {
        guard path.hasPrefix("/") else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
