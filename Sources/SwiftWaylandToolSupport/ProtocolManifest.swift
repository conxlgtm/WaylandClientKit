import Foundation

public struct ProtocolManifest: Codable, Sendable {
    public var protocols: [ProtocolEntry]
}

public struct ProtocolEntry: Codable, Sendable, Equatable {
    public var name: String
    public var localPath: String
    public var upstreamProject: String
    public var upstreamVersion: String
    public var vendoredFromPackage: String
    public var vendoredFromPath: String
    public var sha256: String
    public var stability: String?
    public var swiftWaylandTier: String
    public var apiExposure: String
    public var testStrategy: String
    public var notes: String
    public var sourceResolution: SourceResolution?
    public var generatedHeaderPath: String?
    public var generatedCodePath: String?
    public var scannerHeaderMode: String?
    public var scannerCodeMode: String?

    public var effectiveSourceResolution: SourceResolution {
        sourceResolution ?? SourceResolution.default(for: self)
    }

    public var effectiveGeneratedHeaderPath: String {
        generatedHeaderPath ?? defaultGeneratedHeaderPath
    }

    public var effectiveGeneratedCodePath: String {
        generatedCodePath ?? defaultGeneratedCodePath
    }

    public var defaultGeneratedHeaderPath: String {
        "Sources/CWaylandProtocols/include/generated/\(generatedRelativeDirectory)/\(generatedBaseName)-client-protocol.h"
    }

    public var defaultGeneratedCodePath: String {
        "Sources/CWaylandProtocols/generated/\(generatedRelativeDirectory)/\(generatedBaseName)-protocol.c"
    }

    public var effectiveHeaderMode: String {
        scannerHeaderMode ?? "client-header"
    }

    public var effectiveCodeMode: String {
        scannerCodeMode ?? "private-code"
    }

    public var generatedRelativeDirectory: String {
        let prefix = "protocols/upstream/"
        let path = localPath.hasPrefix(prefix) ? String(localPath.dropFirst(prefix.count)) : localPath
        return path.split(separator: "/").dropLast().joined(separator: "/")
    }

    public var generatedBaseName: String {
        URL(fileURLWithPath: localPath).deletingPathExtension().lastPathComponent
    }
}

public struct SourceResolution: Codable, Sendable, Equatable {
    public var strategy: String
    public var environmentOverride: String?
    public var pkgConfigPackage: String?
    public var pkgConfigVariable: String?
    public var relativeSourceCandidates: [String]
    public var absoluteFallbackCandidates: [String]

    public static func `default`(for entry: ProtocolEntry) -> SourceResolution {
        let info = ProtocolSourceDefaults.info(for: entry)
        return SourceResolution(
            strategy: "pkg-config-with-fallbacks",
            environmentOverride: info.environmentOverride,
            pkgConfigPackage: info.pkgConfigPackage,
            pkgConfigVariable: "pkgdatadir",
            relativeSourceCandidates: info.relativeCandidates,
            absoluteFallbackCandidates: info.absoluteFallbacks
        )
    }
}

public enum ProtocolSourceDefaults {
    public struct Info: Sendable {
        public var environmentOverride: String?
        public var pkgConfigPackage: String?
        public var relativeCandidates: [String]
        public var absoluteFallbacks: [String]
    }

    public static func info(for entry: ProtocolEntry) -> Info {
        if entry.name == "wayland-core" {
            return Info(
                environmentOverride: "WAYLAND_CORE_XML_SOURCE",
                pkgConfigPackage: "wayland-client",
                relativeCandidates: ["wayland.xml"],
                absoluteFallbacks: [
                    "/usr/share/wayland/wayland.xml",
                    "/usr/local/share/wayland/wayland.xml",
                ]
            )
        }

        let local = entry.localPath
        let protocolRelative: String
        if local.contains("/stable/") {
            protocolRelative = localComponent(after: "stable/", in: local)
                .map { "stable/\($0)" } ?? URL(fileURLWithPath: local).lastPathComponent
        } else if local.contains("/staging/") {
            protocolRelative = localComponent(after: "staging/", in: local)
                .map { "staging/\($0)" } ?? URL(fileURLWithPath: local).lastPathComponent
        } else if local.contains("/legacy-unstable/") {
            protocolRelative = localComponent(after: "legacy-unstable/", in: local)
                .map { "unstable/\($0)" } ?? URL(fileURLWithPath: local).lastPathComponent
        } else {
            protocolRelative = URL(fileURLWithPath: local).lastPathComponent
        }

        return Info(
            environmentOverride: environmentOverrideName(for: entry.name),
            pkgConfigPackage: "wayland-protocols",
            relativeCandidates: [protocolRelative],
            absoluteFallbacks: [
                "/usr/share/wayland-protocols/\(protocolRelative)",
                "/usr/local/share/wayland-protocols/\(protocolRelative)",
            ] + qtFallbacks(for: entry.name)
        )
    }

    private static func localComponent(after marker: String, in path: String) -> String? {
        guard let range = path.range(of: marker) else { return nil }
        return String(path[range.upperBound...])
    }

    private static func environmentOverrideName(for name: String) -> String {
        let trimmed = name
            .replacingOccurrences(of: "-unstable-v1", with: "")
            .replacingOccurrences(of: "-v1", with: "")
            .replacingOccurrences(of: "-", with: "_")
            .uppercased()
        return "\(trimmed)_XML_SOURCE"
    }

    private static func qtFallbacks(for name: String) -> [String] {
        guard name == "xdg-shell" else { return [] }
        return ["/usr/share/qt6/wayland/protocols/xdg-shell/xdg-shell.xml"]
    }
}

public struct ProtocolTooling {
    public let repository: Repository
    public let fileSystem: FileSystem
    public let runner: ProcessRunner
    public let diagnostics: Diagnostics

    public init(
        repository: Repository,
        fileSystem: FileSystem = LocalFileSystem(),
        runner: ProcessRunner = ProcessRunner(),
        diagnostics: Diagnostics = Diagnostics()
    ) {
        self.repository = repository
        self.fileSystem = fileSystem
        self.runner = runner
        self.diagnostics = diagnostics
    }

    public func loadManifest() throws -> ProtocolManifest {
        try JSONHelpers.decode(ProtocolManifest.self, from: repository.url("protocols/manifest.json"))
    }

    public func validateManifest() throws {
        let manifest = try loadManifest()
        var failures: [String] = []
        var seen: Set<String> = []

        let tiers = Set(["required", "optionalFoundation", "previewFoundation", "privateGenerationDependency", "outOfScope"])
        let exposures = Set(["public", "publicCapability", "preview", "internal", "none"])
        let strategies = Set(["unit-and-live", "unit-and-live-when-advertised", "generation-only"])
        let sourceStrategies = Set(["pkg-config-with-fallbacks", "vendored-only"])
        let scannerModes = Set(["client-header", "private-code"])

        for entry in manifest.protocols {
            if !seen.insert(entry.name).inserted {
                failures.append("Duplicate protocol manifest entry: \(entry.name)")
            }
            if !tiers.contains(entry.swiftWaylandTier) {
                failures.append("\(entry.name) has invalid swiftWaylandTier: \(entry.swiftWaylandTier)")
            }
            if !exposures.contains(entry.apiExposure) {
                failures.append("\(entry.name) has invalid apiExposure: \(entry.apiExposure)")
            }
            if !strategies.contains(entry.testStrategy) {
                failures.append("\(entry.name) has invalid testStrategy: \(entry.testStrategy)")
            }
            let localURL = repository.url(entry.localPath)
            if !fileSystem.exists(localURL) {
                failures.append("\(entry.name) localPath does not exist: \(entry.localPath)")
            }
            if !entry.localPath.hasPrefix("protocols/upstream/") {
                failures.append("\(entry.name) localPath must be under protocols/upstream")
            }
            if entry.sourceResolution == nil {
                failures.append("\(entry.name) is missing sourceResolution")
            }
            if entry.generatedHeaderPath == nil {
                failures.append("\(entry.name) is missing generatedHeaderPath")
            }
            if entry.generatedCodePath == nil {
                failures.append("\(entry.name) is missing generatedCodePath")
            }
            if entry.scannerHeaderMode == nil {
                failures.append("\(entry.name) is missing scannerHeaderMode")
            }
            if entry.scannerCodeMode == nil {
                failures.append("\(entry.name) is missing scannerCodeMode")
            }
            if !entry.effectiveGeneratedHeaderPath.hasPrefix("Sources/CWaylandProtocols/include/generated/") {
                failures.append("\(entry.name) generated header path is outside generated include directory")
            }
            if !entry.effectiveGeneratedCodePath.hasPrefix("Sources/CWaylandProtocols/generated/") {
                failures.append("\(entry.name) generated code path is outside generated source directory")
            }
            if !scannerModes.contains(entry.effectiveHeaderMode) {
                failures.append("\(entry.name) has invalid scanner header mode: \(entry.effectiveHeaderMode)")
            }
            if !scannerModes.contains(entry.effectiveCodeMode) {
                failures.append("\(entry.name) has invalid scanner code mode: \(entry.effectiveCodeMode)")
            }
            let source = entry.effectiveSourceResolution
            if !sourceStrategies.contains(source.strategy) {
                failures.append("\(entry.name) has invalid source-resolution strategy: \(source.strategy)")
            }
            if source.pkgConfigPackage != nil && source.pkgConfigVariable == nil {
                failures.append("\(entry.name) pkg-config source requires a variable")
            }
            if source.relativeSourceCandidates.isEmpty && source.absoluteFallbackCandidates.isEmpty && source.environmentOverride == nil {
                failures.append("\(entry.name) has no source candidates")
            }
        }

        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }

        diagnostics.success("protocol manifest metadata is complete")
    }

    public func normalizeManifestMetadata() throws {
        var manifest = try loadManifest()
        manifest.protocols = manifest.protocols.map { entry in
            var normalized = entry
            normalized.sourceResolution = entry.effectiveSourceResolution
            normalized.generatedHeaderPath = entry.defaultGeneratedHeaderPath
            normalized.generatedCodePath = entry.defaultGeneratedCodePath
            normalized.scannerHeaderMode = entry.effectiveHeaderMode
            normalized.scannerCodeMode = entry.effectiveCodeMode
            return normalized
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(manifest)
        let text = String(decoding: data, as: UTF8.self) + "\n"
        try fileSystem.writeText(text, to: repository.url("protocols/manifest.json"))
        diagnostics.success("protocol manifest metadata normalized")
    }

    public func resolvedSources() throws -> [(ProtocolEntry, URL?)] {
        try loadManifest().protocols.map { entry in
            (entry, try resolveSource(for: entry))
        }
    }

    public func resolveSource(for entry: ProtocolEntry) throws -> URL? {
        let source = entry.effectiveSourceResolution
        if let name = source.environmentOverride,
            let value = runner.environment[name],
            !value.isEmpty
        {
            let url = URL(fileURLWithPath: value)
            if fileSystem.exists(url) {
                return url
            }
        }

        var candidates: [URL] = []
        if let package = source.pkgConfigPackage, let variable = source.pkgConfigVariable {
            let result = try runner.run(
                "pkg-config",
                ["--variable=\(variable)", package],
                workingDirectory: repository.root,
                requireSuccess: false
            )
            let base = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !base.isEmpty {
                let normalizedBase = base.hasPrefix("//") ? String(base.dropFirst()) : base
                candidates.append(contentsOf: source.relativeSourceCandidates.map {
                    URL(fileURLWithPath: normalizedBase).appendingPathComponent($0)
                })
            }
        }

        candidates.append(contentsOf: source.absoluteFallbackCandidates.map { URL(fileURLWithPath: $0) })
        candidates.append(repository.url(entry.localPath))
        return candidates.first { fileSystem.exists($0) }
    }

    public func syncProtocols() throws {
        for (entry, source) in try resolvedSources() {
            guard let source else {
                throw ToolError("missing XML source for \(entry.name)", exitCode: ToolExitCode.environment)
            }
            let destination = repository.url(entry.localPath)
            if source.standardizedFileURL != destination.standardizedFileURL {
                try fileSystem.copyItem(at: source, to: destination)
            }
            diagnostics.success("\(entry.name): \(source.path)")
        }
    }

    public func generateProtocols() throws {
        let manifest = try loadManifest()
        let scanner = try runner.executableURL(for: "wayland-scanner").path
        let includeRoot = repository.url("Sources/CWaylandProtocols/include/generated")
        let sourceRoot = repository.url("Sources/CWaylandProtocols/generated")
        try fileSystem.removeItem(includeRoot)
        try fileSystem.removeItem(sourceRoot)

        for entry in manifest.protocols {
            let xml = repository.url(entry.localPath)
            guard fileSystem.exists(xml) else {
                throw ToolError("missing vendored protocol XML: \(entry.localPath)", exitCode: ToolExitCode.data)
            }
            let header = repository.url(entry.effectiveGeneratedHeaderPath)
            let code = repository.url(entry.effectiveGeneratedCodePath)
            try fileSystem.createDirectory(header.deletingLastPathComponent())
            try fileSystem.createDirectory(code.deletingLastPathComponent())
            try runner.run(scanner, [entry.effectiveHeaderMode, xml.path, header.path], workingDirectory: repository.root)
            try runner.run(scanner, [entry.effectiveCodeMode, xml.path, code.path], workingDirectory: repository.root)
            try normalizeGeneratedFile(header)
            try normalizeGeneratedFile(code)
        }

        diagnostics.success("generated Wayland protocol artifacts")
    }

    public func verifyGenerated() throws {
        let snapshot = try fileSystem.createTemporaryDirectory(prefix: "swiftwayland-generated")
        defer { try? fileSystem.removeItem(snapshot) }

        let paths = [
            "protocols",
            "Sources/CWaylandProtocols/include/generated",
            "Sources/CWaylandProtocols/generated",
        ]
        for path in paths {
            let source = repository.url(path)
            guard fileSystem.exists(source) else {
                throw ToolError("missing generated verification path: \(path)", exitCode: ToolExitCode.data)
            }
            try fileSystem.copyItem(at: source, to: snapshot.appendingPathComponent(path))
        }

        try generateProtocols()

        var failures: [String] = []
        for path in paths {
            let expected = snapshot.appendingPathComponent(path)
            let actual = repository.url(path)
            failures.append(contentsOf: try directoryDifferences(expected: expected, actual: actual, label: path))
        }

        guard failures.isEmpty else {
            throw ToolError(
                "generated protocol artifacts are not up to date\n" + failures.joined(separator: "\n"),
                exitCode: ToolExitCode.data
            )
        }

        diagnostics.success("generated artifacts are up to date")
    }

    private func normalizeGeneratedFile(_ url: URL) throws {
        let lines = try fileSystem.readText(url)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var normalized = lines.map { line -> String? in
            var value = line
            while value.last == " " || value.last == "\t" {
                value.removeLast()
            }
            if value.hasPrefix("/* Generated by wayland-scanner ") {
                value = "/* Generated by wayland-scanner */"
            }
            if value == "#include <stdbool.h>" {
                return nil
            }
            if value.range(of: #"^\s+\* @deprecated Deprecated since version [0-9]+$"#, options: .regularExpression) != nil {
                return nil
            }
            return value
        }.compactMap { $0 }

        while normalized.last == "" {
            normalized.removeLast()
        }
        try fileSystem.writeText(normalized.joined(separator: "\n") + "\n", to: url)
    }

    private func directoryDifferences(expected: URL, actual: URL, label: String) throws -> [String] {
        let expectedFiles = try relativeFiles(root: expected)
        let actualFiles = try relativeFiles(root: actual)
        var failures: [String] = []

        for file in expectedFiles.subtracting(actualFiles).sorted() {
            failures.append("missing generated file in \(label): \(file)")
        }
        for file in actualFiles.subtracting(expectedFiles).sorted() {
            failures.append("unexpected generated file in \(label): \(file)")
        }
        for file in expectedFiles.intersection(actualFiles).sorted() {
            let lhs = expected.appendingPathComponent(file)
            let rhs = actual.appendingPathComponent(file)
            if try !fileSystem.filesEqual(lhs, rhs) {
                failures.append("changed generated file in \(label): \(file)")
            }
        }
        return failures
    }

    private func relativeFiles(root: URL) throws -> Set<String> {
        Set(try fileSystem.walk(root, includingDirectories: false).map { url in
            let path = url.path
            let rootPath = root.path
            return String(path.dropFirst(rootPath.count + 1))
        })
    }
}
