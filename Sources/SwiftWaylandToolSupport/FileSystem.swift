import Foundation

public protocol FileSystem: Sendable {
    func exists(_ url: URL) -> Bool
    func isDirectory(_ url: URL) -> Bool
    func isExecutable(_ url: URL) -> Bool
    func readText(_ url: URL) throws -> String
    func readData(_ url: URL) throws -> Data
    func writeText(_ text: String, to url: URL) throws
    func writeData(_ data: Data, to url: URL) throws
    func createDirectory(_ url: URL) throws
    func createTemporaryDirectory(prefix: String) throws -> URL
    func copyItem(at source: URL, to destination: URL) throws
    func removeItem(_ url: URL) throws
    func walk(_ root: URL, includingDirectories: Bool) throws -> [URL]
    func filesEqual(_ lhs: URL, _ rhs: URL) throws -> Bool
}

public struct LocalFileSystem: FileSystem {
    private let manager = FileManager.default

    public init() {
        // FileManager.default is the complete local filesystem state.
    }

    public func exists(_ url: URL) -> Bool {
        manager.fileExists(atPath: url.path)
    }

    public func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
        return isDirectory.boolValue
    }

    public func isExecutable(_ url: URL) -> Bool {
        manager.isExecutableFile(atPath: url.path)
    }

    public func readText(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    public func readData(_ url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func writeText(_ text: String, to url: URL) throws {
        try createDirectory(url.deletingLastPathComponent())
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    public func writeData(_ data: Data, to url: URL) throws {
        try createDirectory(url.deletingLastPathComponent())
        try data.write(to: url, options: .atomic)
    }

    public func createDirectory(_ url: URL) throws {
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func createTemporaryDirectory(prefix: String) throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
        let url = base.appendingPathComponent("\(prefix).\(UUID().uuidString)")
        try createDirectory(url)
        return url
    }

    public func copyItem(at source: URL, to destination: URL) throws {
        try createDirectory(destination.deletingLastPathComponent())
        if exists(destination) {
            try removeItem(destination)
        }
        try manager.copyItem(at: source, to: destination)
    }

    public func removeItem(_ url: URL) throws {
        guard exists(url) else { return }
        try manager.removeItem(at: url)
    }

    public func walk(_ root: URL, includingDirectories: Bool = false) throws -> [URL] {
        guard exists(root) else { return [] }
        guard
            let enumerator = manager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true, !includingDirectories {
                continue
            }
            urls.append(url)
        }
        return urls.sorted { $0.path < $1.path }
    }

    public func filesEqual(_ lhs: URL, _ rhs: URL) throws -> Bool {
        try readData(lhs) == readData(rhs)
    }
}
