import Foundation

public struct DocumentationLinkVerifier {
    public let repository: Repository
    public let fileSystem: FileSystem

    public init(
        repository: Repository,
        fileSystem: FileSystem = LocalFileSystem()
    ) {
        self.repository = repository
        self.fileSystem = fileSystem
    }

    public func verify(files: [URL]) throws {
        let inlineRegex = try NSRegularExpression(pattern: #"!?\[[^\]\n]+\]\(([^)\n]+)\)"#)
        let referenceRegex = try NSRegularExpression(pattern: #"^\s{0,3}\[[^\]\n]+\]:\s*(.+)$"#)
        var failures: [String] = []

        for file in files {
            let text = try fileSystem.readText(file)
            let anchors = markdownAnchors(in: text)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(
                String.init)
            var inFence = false

            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    inFence.toggle()
                    continue
                }
                guard !inFence else { continue }

                let lineNumber = index + 1
                failures.append(
                    contentsOf: linkFailures(
                        in: line,
                        regex: inlineRegex,
                        file: file,
                        lineNumber: lineNumber,
                        anchors: anchors)
                )
                failures.append(
                    contentsOf: linkFailures(
                        in: line,
                        regex: referenceRegex,
                        file: file,
                        lineNumber: lineNumber,
                        anchors: anchors)
                )
            }
        }

        guard failures.isEmpty else {
            throw ToolError(failures.joined(separator: "\n"), exitCode: ToolExitCode.data)
        }
    }

    private func linkFailures(
        in line: String,
        regex: NSRegularExpression,
        file: URL,
        lineNumber: Int,
        anchors sourceAnchors: Set<String>
    ) -> [String] {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let linkRange = Range(match.range(at: 1), in: line) else { return nil }
            return validate(
                rawDestination: String(line[linkRange]),
                sourceFile: file,
                sourceLine: lineNumber,
                sourceAnchors: sourceAnchors)
        }
    }

    private func validate(
        rawDestination: String,
        sourceFile: URL,
        sourceLine: Int,
        sourceAnchors: Set<String>
    ) -> String? {
        let destination = markdownDestination(rawDestination)
        guard !destination.isEmpty, isLocal(destination) else { return nil }

        let parts = destination.split(
            separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let pathPart = parts.first.map(String.init) ?? ""
        let fragment = parts.count == 2 ? String(parts[1]) : nil
        let target =
            pathPart.isEmpty
            ? sourceFile
            : sourceFile.deletingLastPathComponent()
                .appendingPathComponent(pathPart.removingPercentEncoding ?? pathPart)
                .standardizedFileURL

        guard repository.contains(target) else {
            return "\(repository.relativePath(sourceFile)):\(sourceLine): "
                + "local Markdown link escapes the repository: \(destination)"
        }
        guard fileSystem.exists(target) else {
            return "\(repository.relativePath(sourceFile)):\(sourceLine): "
                + "broken local Markdown link: \(destination)"
        }

        guard let fragment, !fragment.isEmpty, target.pathExtension == "md" else {
            return nil
        }

        let anchors: Set<String>
        if target.standardizedFileURL == sourceFile.standardizedFileURL {
            anchors = sourceAnchors
        } else {
            do {
                anchors = markdownAnchors(in: try fileSystem.readText(target))
            } catch {
                return "\(repository.relativePath(sourceFile)):\(sourceLine): "
                    + "unreadable local Markdown link target: \(destination)"
            }
        }

        let normalizedAnchor = fragment.removingPercentEncoding ?? fragment
        guard anchors.contains(normalizedAnchor) else {
            return "\(repository.relativePath(sourceFile)):\(sourceLine): "
                + "broken local Markdown anchor: \(destination)"
        }
        return nil
    }

    private func markdownDestination(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<"), let end = trimmed.firstIndex(of: ">") {
            let start = trimmed.index(after: trimmed.startIndex)
            return String(trimmed[start..<end])
        }
        return trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
    }

    private func isLocal(_ destination: String) -> Bool {
        guard !destination.hasPrefix("//") else { return false }
        guard let colon = destination.firstIndex(of: ":") else { return true }
        let scheme = destination[..<colon]
        return scheme.contains("/") || scheme.contains("#")
    }

    private func markdownAnchors(in text: String) -> Set<String> {
        var anchors: Set<String> = []
        var counts: [String: Int] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            guard let title = headingTitle(line) else { continue }
            let base = markdownAnchor(for: title)
            let count = counts[base, default: 0]
            counts[base] = count + 1
            anchors.insert(count == 0 ? base : "\(base)-\(count)")
        }
        return anchors
    }

    private func headingTitle(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let markers = trimmed.prefix { $0 == "#" }
        guard 1...6 ~= markers.count else { return nil }
        let afterMarkers = trimmed.dropFirst(markers.count)
        guard afterMarkers.first?.isWhitespace == true else { return nil }
        return String(afterMarkers).trimmingCharacters(in: .whitespaces)
    }

    private func markdownAnchor(for title: String) -> String {
        var output = ""
        for scalar in title.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar.value == 45
                || scalar.value == 95
            {
                output.unicodeScalars.append(scalar)
            } else if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                output.append("-")
            }
        }
        while output.contains("--") {
            output = output.replacingOccurrences(of: "--", with: "-")
        }
        return output.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
