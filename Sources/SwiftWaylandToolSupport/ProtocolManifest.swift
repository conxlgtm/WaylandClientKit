import Foundation

// The manifest model and validator stay together so protocol metadata has one owner.
// swiftlint:disable cyclomatic_complexity file_length function_body_length type_body_length

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
        "Sources/CWaylandProtocols/include/generated/"
            + "\(generatedRelativeDirectory)/\(generatedBaseName)-client-protocol.h"
    }

    public var defaultGeneratedCodePath: String {
        "Sources/CWaylandProtocols/generated/"
            + "\(generatedRelativeDirectory)/\(generatedBaseName)-protocol.c"
    }

    public var effectiveHeaderMode: String {
        scannerHeaderMode ?? "client-header"
    }

    public var effectiveCodeMode: String {
        scannerCodeMode ?? "private-code"
    }

    public var generatedRelativeDirectory: String {
        let prefix = "protocols/upstream/"
        let path =
            localPath.hasPrefix(prefix) ? String(localPath.dropFirst(prefix.count)) : localPath
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
            protocolRelative =
                localComponent(after: "stable/", in: local)
                .map { "stable/\($0)" } ?? URL(fileURLWithPath: local).lastPathComponent
        } else if local.contains("/staging/") {
            protocolRelative =
                localComponent(after: "staging/", in: local)
                .map { "staging/\($0)" } ?? URL(fileURLWithPath: local).lastPathComponent
        } else if local.contains("/legacy-unstable/") {
            protocolRelative =
                localComponent(after: "legacy-unstable/", in: local)
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
        let trimmed =
            name
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
        try JSONHelpers.decode(
            ProtocolManifest.self, from: repository.url("protocols/manifest.json"))
    }

    public func validateManifest() throws {
        let manifest = try loadManifest()
        var failures: [String] = []
        var seen: Set<String> = []

        let tiers = Set([
            "required", "optionalFoundation", "previewFoundation", "privateGenerationDependency",
            "outOfScope",
        ])
        let exposures = Set(["public", "publicCapability", "preview", "internal", "none"])
        let strategies = Set(["unit-and-live", "unit-and-live-when-advertised", "generation-only"])
        let sourceStrategies = Set(["pkg-config-with-fallbacks", "vendored-only"])
        let scannerModes = Set(["client-header", "private-code"])

        for entry in manifest.protocols {
            diagnostics.verbose("validating protocol manifest entry: \(entry.name)")
            if !seen.insert(entry.name).inserted {
                failures.append("Duplicate protocol manifest entry: \(entry.name)")
            }
            if !tiers.contains(entry.swiftWaylandTier) {
                failures.append(
                    "\(entry.name) has invalid swiftWaylandTier: \(entry.swiftWaylandTier)")
            }
            if !exposures.contains(entry.apiExposure) {
                failures.append("\(entry.name) has invalid apiExposure: \(entry.apiExposure)")
            }
            if !strategies.contains(entry.testStrategy) {
                failures.append("\(entry.name) has invalid testStrategy: \(entry.testStrategy)")
            }
            let localURL = validateRepositoryPath(
                entry.localPath,
                field: "localPath",
                protocolName: entry.name,
                requiredRoot: "protocols/upstream",
                failures: &failures
            )
            if let localURL, !fileSystem.exists(localURL) {
                failures.append("\(entry.name) localPath does not exist: \(entry.localPath)")
            }
            if let localURL, fileSystem.exists(localURL) {
                validateRepositoryFileIsNotSymlink(
                    localURL,
                    field: "localPath",
                    protocolName: entry.name,
                    path: entry.localPath,
                    failures: &failures)
                validateSHA256(
                    entry.sha256,
                    for: localURL,
                    protocolName: entry.name,
                    label: "vendored XML",
                    failures: &failures)
            }
            if !isValidSHA256(entry.sha256) {
                failures.append("\(entry.name) sha256 must be a 64-character lowercase hex digest")
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
            _ = validateRepositoryPath(
                entry.effectiveGeneratedHeaderPath,
                field: "generatedHeaderPath",
                protocolName: entry.name,
                requiredRoot: "Sources/CWaylandProtocols/include/generated",
                failures: &failures
            )
            _ = validateRepositoryPath(
                entry.effectiveGeneratedCodePath,
                field: "generatedCodePath",
                protocolName: entry.name,
                requiredRoot: "Sources/CWaylandProtocols/generated",
                failures: &failures
            )
            if !scannerModes.contains(entry.effectiveHeaderMode) {
                failures.append(
                    "\(entry.name) has invalid scanner header mode: \(entry.effectiveHeaderMode)")
            }
            if !scannerModes.contains(entry.effectiveCodeMode) {
                failures.append(
                    "\(entry.name) has invalid scanner code mode: \(entry.effectiveCodeMode)")
            }
            let source = entry.effectiveSourceResolution
            if !sourceStrategies.contains(source.strategy) {
                failures.append(
                    "\(entry.name) has invalid source-resolution strategy: \(source.strategy)")
            }
            if source.pkgConfigPackage != nil, source.pkgConfigVariable == nil {
                failures.append("\(entry.name) pkg-config source requires a variable")
            }
            if source.relativeSourceCandidates.isEmpty,
                source.absoluteFallbackCandidates.isEmpty,
                source.environmentOverride == nil
            {
                failures.append("\(entry.name) has no source candidates")
            }
            for candidate in source.relativeSourceCandidates {
                validateRelativeCandidate(
                    candidate,
                    field: "relativeSourceCandidates",
                    protocolName: entry.name,
                    failures: &failures)
            }
            for candidate in source.absoluteFallbackCandidates {
                validateAbsoluteCandidate(
                    candidate,
                    field: "absoluteFallbackCandidates",
                    protocolName: entry.name,
                    failures: &failures)
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
        guard let manifestText = String(data: data, encoding: .utf8) else {
            throw ToolError(
                "failed to encode protocol manifest as UTF-8",
                exitCode: ToolExitCode.data)
        }
        let text = manifestText + "\n"
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
                candidates.append(
                    contentsOf: source.relativeSourceCandidates.map { candidate in
                        URL(fileURLWithPath: normalizedBase).appendingPathComponent(candidate)
                    })
            }
        }

        candidates.append(
            contentsOf: source.absoluteFallbackCandidates.map { URL(fileURLWithPath: $0) })
        candidates.append(repository.url(entry.localPath))
        return candidates.first { fileSystem.exists($0) }
    }

    public func syncProtocols() throws {
        try validateManifest()
        for (entry, source) in try resolvedSources() {
            guard let source else {
                throw ToolError(
                    "missing XML source for \(entry.name)", exitCode: ToolExitCode.environment)
            }
            try validateSourceHash(entry: entry, source: source)
            let destination = repository.url(entry.localPath)
            if source.standardizedFileURL != destination.standardizedFileURL {
                let data = try fileSystem.readData(source)
                try fileSystem.removeItem(destination)
                try fileSystem.writeData(data, to: destination)
            }
            diagnostics.success("\(entry.name): \(source.path)")
        }
    }

    public func generateProtocols() throws {
        try generateProtocols(outputRoot: repository.root, validateFirst: true)
    }

    private func generateProtocols(outputRoot: URL, validateFirst: Bool) throws {
        if validateFirst {
            try validateManifest()
        }
        let manifest = try loadManifest()
        let scanner = try RepositoryNixTools(
            repository: repository,
            fileSystem: fileSystem,
            runner: runner,
            diagnostics: diagnostics
        ).executablePath(for: "wayland-scanner", probeArguments: ["--version"])
        let includeRoot = outputRoot.appendingPathComponent(
            "Sources/CWaylandProtocols/include/generated")
        let sourceRoot = outputRoot.appendingPathComponent("Sources/CWaylandProtocols/generated")
        try fileSystem.removeItem(includeRoot)
        try fileSystem.removeItem(sourceRoot)

        for entry in manifest.protocols {
            let xml = repository.url(entry.localPath)
            guard fileSystem.exists(xml) else {
                throw ToolError(
                    "missing vendored protocol XML: \(entry.localPath)", exitCode: ToolExitCode.data
                )
            }
            let header = outputRoot.appendingPathComponent(entry.effectiveGeneratedHeaderPath)
            let code = outputRoot.appendingPathComponent(entry.effectiveGeneratedCodePath)
            try fileSystem.createDirectory(header.deletingLastPathComponent())
            try fileSystem.createDirectory(code.deletingLastPathComponent())
            try runner.run(
                scanner, [entry.effectiveHeaderMode, xml.path, header.path],
                workingDirectory: repository.root)
            try runner.run(
                scanner, [entry.effectiveCodeMode, xml.path, code.path],
                workingDirectory: repository.root)
            try normalizeGeneratedFile(header)
            try normalizeGeneratedFile(code)
        }

        diagnostics.success("generated Wayland protocol artifacts")
    }

    public func verifyGenerated() throws {
        try validateManifest()

        let generated = try fileSystem.createTemporaryDirectory(prefix: "swiftwayland-generated")
        defer {
            do {
                try fileSystem.removeItem(generated)
            } catch {
                // Cleanup best-effort only.
            }
        }

        try generateProtocols(outputRoot: generated, validateFirst: false)

        var failures: [String] = []
        let paths = [
            "Sources/CWaylandProtocols/include/generated",
            "Sources/CWaylandProtocols/generated",
        ]
        for path in paths {
            let expected = generated.appendingPathComponent(path)
            let actual = repository.url(path)
            guard fileSystem.exists(actual) else {
                throw ToolError(
                    "missing generated verification path: \(path)", exitCode: ToolExitCode.data)
            }
            failures.append(
                contentsOf: try directoryDifferences(
                    expected: expected, actual: actual, label: path))
        }

        guard failures.isEmpty else {
            throw ToolError(
                "generated protocol artifacts are not up to date\n"
                    + failures.joined(separator: "\n"),
                exitCode: ToolExitCode.data
            )
        }

        diagnostics.success("generated artifacts are up to date")
    }

    private func validateRepositoryPath(
        _ path: String,
        field: String,
        protocolName: String,
        requiredRoot: String,
        failures: inout [String]
    ) -> URL? {
        guard
            validateRelativePathComponents(
                path,
                field: field,
                protocolName: protocolName,
                failures: &failures
            )
        else {
            return nil
        }

        let root = repository.url(requiredRoot).standardizedFileURL
        let resolved = repository.url(path).standardizedFileURL
        guard isContained(resolved, in: root) else {
            failures.append(
                "\(protocolName) \(field) escapes \(requiredRoot): \(path)")
            return nil
        }
        return resolved
    }

    private func validateRelativeCandidate(
        _ path: String,
        field: String,
        protocolName: String,
        failures: inout [String]
    ) {
        _ = validateRelativePathComponents(
            path,
            field: field,
            protocolName: protocolName,
            failures: &failures)
    }

    private func validateAbsoluteCandidate(
        _ path: String,
        field: String,
        protocolName: String,
        failures: inout [String]
    ) {
        guard !path.isEmpty else {
            failures.append("\(protocolName) \(field) must not be empty")
            return
        }
        guard path.hasPrefix("/") else {
            failures.append("\(protocolName) \(field) must be absolute: \(path)")
            return
        }
        if pathComponents(for: path).contains("..") {
            failures.append("\(protocolName) \(field) must not contain '..': \(path)")
        }
    }

    private func validateRepositoryFileIsNotSymlink(
        _ url: URL,
        field: String,
        protocolName: String,
        path: String,
        failures: inout [String]
    ) {
        do {
            if try fileSystem.isSymbolicLink(url) {
                failures.append("\(protocolName) \(field) must not be a symlink: \(path)")
            }
        } catch {
            failures.append("\(protocolName) \(field) symlink status could not be read: \(error)")
        }
    }

    private func validateRelativePathComponents(
        _ path: String,
        field: String,
        protocolName: String,
        failures: inout [String]
    ) -> Bool {
        guard !path.isEmpty else {
            failures.append("\(protocolName) \(field) must not be empty")
            return false
        }
        guard !path.hasPrefix("/") else {
            failures.append("\(protocolName) \(field) must be relative: \(path)")
            return false
        }

        let components = pathComponents(for: path)
        if components.contains("") {
            failures.append(
                "\(protocolName) \(field) must not contain empty path components: "
                    + path)
            return false
        }
        if components.contains(".") || components.contains("..") {
            failures.append("\(protocolName) \(field) must not contain '.' or '..': \(path)")
            return false
        }
        return true
    }

    private func pathComponents(for path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    }

    private func isContained(_ url: URL, in root: URL) -> Bool {
        let rootPath = root.path
        let path = url.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private func isValidSHA256(_ value: String) -> Bool {
        SHA256Checksum.isValid(value)
    }

    private func validateSHA256(
        _ expected: String,
        for url: URL,
        protocolName: String,
        label: String,
        failures: inout [String]
    ) {
        guard isValidSHA256(expected) else { return }
        do {
            let actual = try sha256(of: url)
            if actual != expected {
                failures.append(
                    "\(protocolName) \(label) checksum mismatch: expected \(expected), "
                        + "got \(actual)"
                )
            }
        } catch {
            failures.append("\(protocolName) \(label) checksum could not be read: \(error)")
        }
    }

    private func validateSourceHash(entry: ProtocolEntry, source: URL) throws {
        let actual = try sha256(of: source)
        guard actual == entry.sha256 else {
            throw ToolError(
                "\(entry.name) XML source checksum mismatch: expected \(entry.sha256), "
                    + "got \(actual)",
                exitCode: ToolExitCode.data)
        }
    }

    private func sha256(of url: URL) throws -> String {
        try SHA256Checksum.compute(of: url, fileSystem: fileSystem)
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
            if value.range(
                of: #"^\s+\* @deprecated Deprecated since version [0-9]+$"#,
                options: .regularExpression) != nil
            {
                return nil
            }
            return value
        }.compactMap(\.self)

        while normalized.last?.isEmpty == true {
            normalized.removeLast()
        }
        try fileSystem.writeText(normalized.joined(separator: "\n") + "\n", to: url)
    }

    private func directoryDifferences(expected: URL, actual: URL, label: String) throws -> [String]
    {
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
        Set(
            try fileSystem.walk(root, includingDirectories: false).map { url in
                let path = url.path
                let rootPath = root.path
                return String(path.dropFirst(rootPath.count + 1))
            })
    }
}

// swiftlint:enable cyclomatic_complexity file_length function_body_length type_body_length
