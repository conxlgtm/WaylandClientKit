import Foundation

/// Supplements compiler symbol graphs with ownership markers that Swift's
/// symbol-graph emitter currently omits from type and accessor declarations.
///
/// Source ownership is read from Swift's parse-only AST dump. That keeps
/// comments, literals, source formatting, and declaration modifier order out
/// of the API model without requiring imported modules to be type checked a
/// second time.
public struct SourceOwnershipAPIBaseline {
    public let fileSystem: FileSystem
    public let runner: ProcessRunner
    public let swiftCompilerExecutable: String

    public init(
        fileSystem: FileSystem = LocalFileSystem(),
        runner: ProcessRunner = ProcessRunner(),
        swiftCompilerExecutable: String = "swiftc"
    ) {
        self.fileSystem = fileSystem
        self.runner = runner
        self.swiftCompilerExecutable = swiftCompilerExecutable
    }

    public func render(moduleSources: [String: URL]) throws -> String {
        var records = Set<String>()
        for (module, root) in moduleSources {
            let sources = try fileSystem.walk(root, includingDirectories: false)
                .filter { $0.pathExtension == "swift" }
                .sorted { $0.path < $1.path }
            var parsedSources: [ParsedOwnershipSource] = []
            for source in sources {
                let sourceText = try fileSystem.readText(source)
                guard sourceText.contains("Copyable") || sourceText.contains("borrowing") else {
                    continue
                }
                let result = try runner.run(
                    swiftCompilerExecutable,
                    [
                        "-frontend",
                        "-dump-parse",
                        "-D",
                        "SWIFT_PACKAGE",
                        source.path,
                    ],
                    workingDirectory: root
                )
                parsedSources.append(
                    ParsedOwnershipSource(
                        source: sourceText,
                        declarations: SwiftParseDumpParser().parse(result.stdout)
                    )
                )
            }
            records.formUnion(
                SourceOwnershipExtractor().records(module: module, sources: parsedSources)
            )
        }

        var lines = [
            "## Ownership Markers",
            "",
            "Swift symbol graphs omit `~Copyable` and accessor ownership. These",
            "compiler-parsed source declarations supplement",
            "the semantic symbol records above.",
            "",
            "```text",
        ]
        lines.append(contentsOf: records.sorted())
        lines.append(contentsOf: ["```", ""])
        return lines.joined(separator: "\n")
    }
}

private struct SwiftParseDumpParser {
    func parse(_ dump: String) -> [ParsedSwiftDeclaration] {
        var declarations: [ParsedSwiftDeclaration] = []
        var stack: [Int] = []

        for line in dump.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)
            let indentation = text.prefix { $0 == " " }.count
            while let last = stack.last, declarations[last].indentation >= indentation {
                stack.removeLast()
            }

            guard let nodeKind = nodeKind(in: text) else { continue }
            if nodeKind.hasSuffix("_decl") {
                let declaration = ParsedSwiftDeclaration(
                    kind: nodeKind,
                    indentation: indentation,
                    name: firstQuotedValue(in: text),
                    sourceLocation: sourceLocation(in: text),
                    parent: stack.last
                )
                declarations.append(declaration)
                stack.append(declarations.index(before: declarations.endIndex))
            } else if nodeKind == "access_control_attr", text.contains("access_level=public") {
                if let owner = stack.last {
                    declarations[owner].hasPublicAccess = true
                }
            } else if nodeKind == "borrowing_attr", let owner = stack.last {
                declarations[owner].hasBorrowingAttribute = true
            }
        }
        return declarations
    }

    private func nodeKind(in line: String) -> String? {
        let trimmed = line.drop { $0 == " " }
        guard trimmed.first == "(" else { return nil }
        let remainder = trimmed.dropFirst()
        return String(remainder.prefix { !$0.isWhitespace && $0 != ")" })
    }

    private func firstQuotedValue(in line: String) -> String? {
        guard let openingQuote = line.firstIndex(of: "\"") else { return nil }
        var index = line.index(after: openingQuote)
        var value = ""
        var isEscaped = false
        while index < line.endIndex {
            let character = line[index]
            if isEscaped {
                value.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                return value
            } else {
                value.append(character)
            }
            index = line.index(after: index)
        }
        return nil
    }

    private func sourceLocation(in line: String) -> SourceLocation? {
        guard
            let rangeStart = line.range(of: "range=["),
            let rangeEnd = line[rangeStart.upperBound...].range(of: " - ")
        else { return nil }
        let location = line[rangeStart.upperBound..<rangeEnd.lowerBound]
        let components = location.split(separator: ":")
        guard
            components.count >= 3,
            let sourceLine = Int(components[components.count - 2]),
            let sourceColumn = Int(components[components.count - 1])
        else { return nil }
        return SourceLocation(line: sourceLine, column: sourceColumn)
    }
}

private struct SourceOwnershipExtractor {
    func records(
        module: String,
        sources: [ParsedOwnershipSource]
    ) -> Set<String> {
        var noncopyableTypes = Set<String>()
        for source in sources {
            for (index, declaration) in source.declarations.enumerated()
            where declaration.isNominalValueType
                && isExternallyPublic(index, in: source.declarations)
                && NoncopyableInheritanceParser(source: source.source)
                    .containsMarker(at: declaration.sourceLocation)
            {
                if let typeName = typeName(for: index, in: source.declarations) {
                    noncopyableTypes.insert(typeName)
                }
            }
        }

        var records = Set(noncopyableTypes.map { "\(module).\($0)\t~Copyable" })
        for source in sources {
            for (index, declaration) in source.declarations.enumerated()
            where declaration.kind == "var_decl"
                && isPublicMember(index, in: source.declarations)
                && hasBorrowingGetter(index, in: source.declarations)
            {
                guard
                    let containingType = containingTypeName(for: index, in: source.declarations),
                    noncopyableTypes.contains(containingType),
                    let propertyName = declaration.name
                else { continue }
                records.insert(
                    "\(module).\(containingType).\(propertyName)\tborrowing get"
                )
            }
        }
        return records
    }

    private func hasBorrowingGetter(
        _ property: Int,
        in declarations: [ParsedSwiftDeclaration]
    ) -> Bool {
        declarations.indices.contains { index in
            declarations[index].parent == property
                && declarations[index].kind == "accessor_decl"
                && declarations[index].hasBorrowingAttribute
        }
    }

    private func isExternallyPublic(
        _ declaration: Int,
        in declarations: [ParsedSwiftDeclaration]
    ) -> Bool {
        guard isPublicMember(declaration, in: declarations) else { return false }
        var ancestor = declarations[declaration].parent
        while let index = ancestor {
            let node = declarations[index]
            if node.isTypeDeclaration, !isPublicMember(index, in: declarations) {
                return false
            }
            ancestor = node.parent
        }
        return true
    }

    private func isPublicMember(
        _ declaration: Int,
        in declarations: [ParsedSwiftDeclaration]
    ) -> Bool {
        if declarations[declaration].hasPublicAccess {
            return true
        }
        guard let parent = declarations[declaration].parent else { return false }
        return declarations[parent].kind == "extension_decl"
            && declarations[parent].hasPublicAccess
    }

    private func typeName(
        for declaration: Int,
        in declarations: [ParsedSwiftDeclaration]
    ) -> String? {
        guard let name = declarations[declaration].name else { return nil }
        guard let parent = containingTypeName(for: declaration, in: declarations) else {
            return name
        }
        return "\(parent).\(name)"
    }

    private func containingTypeName(
        for declaration: Int,
        in declarations: [ParsedSwiftDeclaration]
    ) -> String? {
        var components: [String] = []
        var ancestor = declarations[declaration].parent
        while let index = ancestor {
            let node = declarations[index]
            if node.kind == "extension_decl", let name = node.name {
                let normalized = name.prefix { $0 != "<" && !$0.isWhitespace }
                components.insert(String(normalized), at: 0)
                break
            }
            if node.isTypeDeclaration, let name = node.name {
                components.insert(name, at: 0)
            }
            ancestor = node.parent
        }
        return components.isEmpty ? nil : components.joined(separator: ".")
    }
}

private struct NoncopyableInheritanceParser {
    let source: String

    func containsMarker(at location: SourceLocation?) -> Bool {
        guard let location else { return false }
        let header = declarationHeader(startingAt: location)
        var angleDepth = 0
        var inheritanceStart: String.Index?
        var inheritanceEnd: String.Index?
        var index = header.startIndex

        while index < header.endIndex {
            let character = header[index]
            if character == "<" {
                angleDepth += 1
                index = header.index(after: index)
                continue
            }
            if character == ">" {
                angleDepth = max(0, angleDepth - 1)
                index = header.index(after: index)
                continue
            }
            if angleDepth == 0, character == ":", inheritanceStart == nil {
                inheritanceStart = header.index(after: index)
                index = header.index(after: index)
                continue
            }
            if angleDepth == 0, character.isLetter || character == "_" {
                let wordStart = index
                repeat {
                    index = header.index(after: index)
                } while index < header.endIndex
                    && (header[index].isLetter || header[index].isNumber || header[index] == "_")
                if header[wordStart..<index] == "where" {
                    inheritanceEnd = wordStart
                    break
                }
                continue
            }
            index = header.index(after: index)
        }

        guard let inheritanceStart else { return false }
        let end = inheritanceEnd ?? header.endIndex
        guard inheritanceStart <= end else { return false }
        let compactInheritance = header[inheritanceStart..<end]
            .filter { !$0.isWhitespace }
        return compactInheritance.contains("~Copyable")
    }

    private func declarationHeader(startingAt location: SourceLocation) -> String {
        let bytes = Array(source.utf8)
        guard let start = utf8Offset(of: location, in: bytes) else { return "" }
        var output: [UInt8] = []
        var index = start
        var blockCommentDepth = 0
        var isLineComment = false

        while index < bytes.count {
            let byte = bytes[index]
            let next = index + 1 < bytes.count ? bytes[index + 1] : nil
            if isLineComment {
                if byte == 0x0A {
                    isLineComment = false
                    output.append(byte)
                }
                index += 1
                continue
            }
            if blockCommentDepth > 0 {
                if byte == 0x2F, next == 0x2A {
                    blockCommentDepth += 1
                    index += 2
                } else if byte == 0x2A, next == 0x2F {
                    blockCommentDepth -= 1
                    index += 2
                } else {
                    index += 1
                }
                continue
            }
            if byte == 0x2F, next == 0x2F {
                isLineComment = true
                index += 2
                continue
            }
            if byte == 0x2F, next == 0x2A {
                output.append(0x20)
                blockCommentDepth = 1
                index += 2
                continue
            }
            if byte == 0x7B {
                break
            }
            output.append(byte)
            index += 1
        }
        return String(bytes: output, encoding: .utf8) ?? ""
    }

    private func utf8Offset(of location: SourceLocation, in bytes: [UInt8]) -> Int? {
        guard location.line > 0, location.column > 0 else { return nil }
        var line = 1
        var offset = 0
        while line < location.line, offset < bytes.count {
            if bytes[offset] == 0x0A {
                line += 1
            }
            offset += 1
        }
        guard line == location.line else { return nil }
        let result = offset + location.column - 1
        return result < bytes.count ? result : nil
    }
}

private struct ParsedOwnershipSource {
    let source: String
    let declarations: [ParsedSwiftDeclaration]
}

private struct ParsedSwiftDeclaration {
    let kind: String
    let indentation: Int
    let name: String?
    let sourceLocation: SourceLocation?
    let parent: Int?
    var hasPublicAccess = false
    var hasBorrowingAttribute = false

    var isNominalValueType: Bool {
        kind == "struct_decl" || kind == "enum_decl"
    }

    var isTypeDeclaration: Bool {
        isNominalValueType || kind == "class_decl" || kind == "protocol_decl"
    }
}

private struct SourceLocation {
    let line: Int
    let column: Int
}
