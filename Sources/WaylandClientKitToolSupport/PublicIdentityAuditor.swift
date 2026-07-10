import Foundation

public struct PublicIdentityAuditor {
    public let repository: Repository
    public let fileSystem: FileSystem

    public init(repository: Repository, fileSystem: FileSystem = LocalFileSystem()) {
        self.repository = repository
        self.fileSystem = fileSystem
    }

    public func verify(update: Bool) throws {
        let reportURL = repository.url("docs/identity-visibility.md")
        let report = try render()
        if update {
            try fileSystem.writeText(report, to: reportURL)
            return
        }
        guard fileSystem.exists(reportURL) else {
            throw ToolError(
                "Missing generated identity visibility audit: docs/identity-visibility.md",
                exitCode: ToolExitCode.data
            )
        }
        guard try fileSystem.readText(reportURL) == report else {
            throw ToolError(
                "Public identity visibility changed; review categories and run "
                    + "swift run wck identity verify --update",
                exitCode: ToolExitCode.data
            )
        }
    }

    public func render() throws -> String {
        let manifest = try loadManifest()
        let declarations = try discoverDeclarations()
        let manifestNames = Set(manifest.identities.map(\.type))
        let declarationNames = Set(declarations.keys)
        let missingCategories =
            declarationNames
            .subtracting(manifestNames)
            .sorted()
        let missingDeclarations = manifestNames.subtracting(declarationNames).sorted()
        guard missingCategories.isEmpty else {
            throw ToolError(
                "Public identities are missing categories: "
                    + missingCategories.joined(separator: ", "),
                exitCode: ToolExitCode.data
            )
        }
        guard missingDeclarations.isEmpty else {
            throw ToolError(
                "Identity categories reference missing public types: "
                    + missingDeclarations.joined(separator: ", "),
                exitCode: ToolExitCode.data
            )
        }

        let records = try auditRecords(manifest: manifest, declarations: declarations)

        var lines = [
            "# Public identity visibility",
            "",
            "This file is generated from `docs/identity-categories.json` and public Swift "
                + "declarations. It records which identities callers may construct and which "
                + "stored values are public.",
            "",
            "Run `swift run wck identity verify --update` after reviewing an intentional "
                + "identity contract change.",
            "",
            "| Type | Category | Constructor | Stored value | Value visibility | Source |",
            "| --- | --- | --- | --- | --- | --- |",
        ]
        lines.append(contentsOf: records.map(render))
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func auditRecords(
        manifest: IdentityManifest,
        declarations: [String: IdentityDeclaration]
    ) throws -> [IdentityAuditRecord] {
        try manifest.identities.map { identity in
            guard let declaration = declarations[identity.type] else {
                throw ToolError("Missing public identity declaration: \(identity.type)")
            }
            let constructor = try constructorVisibility(in: declaration.body)
            let storage = try storageVisibility(
                named: identity.storage,
                in: declaration.body,
                typeName: identity.type
            )
            try validate(
                identity: identity,
                constructor: constructor,
                storage: storage
            )
            return IdentityAuditRecord(
                type: identity.type,
                category: identity.category,
                constructor: constructor,
                storage: identity.storage,
                storageVisibility: storage,
                source: declaration.source
            )
        }.sorted { $0.type < $1.type }
    }

    private func validate(
        identity: IdentityManifestEntry,
        constructor: IdentityAccessLevel,
        storage: IdentityAccessLevel
    ) throws {
        guard constructor == identity.constructor else {
            throw ToolError(
                "\(identity.type) constructor is \(constructor.rawValue), expected "
                    + identity.constructor.rawValue,
                exitCode: ToolExitCode.data
            )
        }
        guard storage == identity.storageVisibility else {
            throw ToolError(
                "\(identity.type).\(identity.storage) is \(storage.rawValue), expected "
                    + identity.storageVisibility.rawValue,
                exitCode: ToolExitCode.data
            )
        }
    }

    private func loadManifest() throws -> IdentityManifest {
        let url = repository.url("docs/identity-categories.json")
        guard fileSystem.exists(url) else {
            throw ToolError(
                "Missing identity category manifest: docs/identity-categories.json",
                exitCode: ToolExitCode.data
            )
        }
        return try JSONDecoder().decode(IdentityManifest.self, from: fileSystem.readData(url))
    }

    private func discoverDeclarations() throws -> [String: IdentityDeclaration] {
        let roots = [
            repository.url("Sources/WaylandClient/Public"),
            repository.url("Sources/WaylandGraphicsPreviewAPI/Public"),
        ]
        let declarationPattern =
            #"\bpublic\s+struct\s+([A-Za-z_][A-Za-z0-9_]*(?:ID|Identity|Token|Serial))\b"#
        let expression = try NSRegularExpression(pattern: declarationPattern)
        var declarations: [String: IdentityDeclaration] = [:]
        for root in roots {
            for url in try fileSystem.walk(root, includingDirectories: false)
            where url.pathExtension == "swift" {
                let source = try fileSystem.readText(url)
                let range = NSRange(source.startIndex..<source.endIndex, in: source)
                for match in expression.matches(in: source, range: range) {
                    guard
                        let nameRange = Range(match.range(at: 1), in: source),
                        let declarationRange = Range(match.range(at: 0), in: source),
                        let openingBrace = source[declarationRange.upperBound...].firstIndex(
                            of: "{"),
                        let closingBrace = matchingClosingBrace(in: source, opening: openingBrace)
                    else {
                        throw ToolError("Malformed public identity declaration in \(url.path)")
                    }
                    let name = String(source[nameRange])
                    guard declarations[name] == nil else {
                        throw ToolError("Duplicate public identity declaration: \(name)")
                    }
                    declarations[name] = IdentityDeclaration(
                        body: String(source[openingBrace...closingBrace]),
                        source: repository.relativePath(url)
                    )
                }
            }
        }
        return declarations
    }

    private func matchingClosingBrace(in source: String, opening: String.Index) -> String.Index? {
        var depth = 0
        var index = opening
        while index < source.endIndex {
            switch source[index] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return index }
            default:
                break
            }
            index = source.index(after: index)
        }
        return nil
    }

    private func constructorVisibility(in body: String) throws -> IdentityAccessLevel {
        try mostVisibleAccess(
            matching: #"\b(?:(public|package|internal|fileprivate|private)\s+)?init\s*\("#,
            in: body
        ) ?? .internal
    }

    private func storageVisibility(
        named storage: String,
        in body: String,
        typeName: String
    ) throws -> IdentityAccessLevel {
        let escapedStorage = NSRegularExpression.escapedPattern(for: storage)
        let pattern =
            #"\b(?:(public|package|internal|fileprivate|private)\s+)?(?:let|var)\s+"#
            + escapedStorage + #"\b"#
        guard let access = try mostVisibleAccess(matching: pattern, in: body) else {
            throw ToolError("\(typeName) is missing stored value \(storage)")
        }
        return access
    }

    private func mostVisibleAccess(
        matching pattern: String,
        in body: String
    ) throws -> IdentityAccessLevel? {
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        return expression.matches(in: body, range: range).compactMap { match in
            guard match.range(at: 1).location != NSNotFound,
                let accessRange = Range(match.range(at: 1), in: body)
            else {
                return IdentityAccessLevel.internal
            }
            return IdentityAccessLevel(rawValue: String(body[accessRange]))
        }.min()
    }

    private func render(_ record: IdentityAuditRecord) -> String {
        "| `\(record.type)` | \(record.category) | `\(record.constructor.rawValue)` | "
            + "`\(record.storage)` | `\(record.storageVisibility.rawValue)` | "
            + "`\(record.source)` |"
    }
}

private struct IdentityManifest: Decodable {
    let identities: [IdentityManifestEntry]
}

private struct IdentityManifestEntry: Decodable {
    let type: String
    let category: String
    let constructor: IdentityAccessLevel
    let storage: String
    let storageVisibility: IdentityAccessLevel
}

private struct IdentityDeclaration {
    let body: String
    let source: String
}

private struct IdentityAuditRecord {
    let type: String
    let category: String
    let constructor: IdentityAccessLevel
    let storage: String
    let storageVisibility: IdentityAccessLevel
    let source: String
}

private enum IdentityAccessLevel: String, Decodable, Comparable {
    case `public`
    case package
    case `internal`
    case `fileprivate`
    case `private`

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .public: 0
        case .package: 1
        case .internal: 2
        case .fileprivate: 3
        case .private: 4
        }
    }
}
