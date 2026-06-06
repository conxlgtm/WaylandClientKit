import Foundation

public struct CompositorEvidenceSummarizer {
    public init() {
        // Stateless summarizer.
    }

    public func summarize(markdown: String) throws -> String {
        let mainRows = try markdownTableRows(afterHeading: "## Matrix", in: markdown)
        let graphicsRows = try markdownTableRows(
            afterHeading: "## Graphics Preview Evidence",
            in: markdown)

        var lines = ["Compositor evidence summary"]
        lines.append("")
        lines.append("Main matrix:")
        if mainRows.isEmpty {
            lines.append("- no compositor matrix rows found")
        } else {
            for row in mainRows {
                lines.append("- \(row.firstCell): \(statusSummary(for: row.cells.dropFirst()))")
            }
        }

        lines.append("")
        lines.append("Graphics preview:")
        if graphicsRows.isEmpty {
            lines.append("- no graphics preview evidence rows found")
        } else {
            for row in graphicsRows {
                let status = graphicsStatusSummary(row: row)
                lines.append("- \(row.firstCell): \(status)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func markdownTableRows(afterHeading heading: String, in markdown: String) throws
        -> [MarkdownTableRow]
    {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(
            String.init)
        guard
            let headingIndex = lines.firstIndex(where: { line in
                line.trimmingCharacters(in: .whitespaces) == heading
            })
        else {
            throw ToolError(
                "compositor matrix heading not found: \(heading)", exitCode: ToolExitCode.data)
        }

        guard let headerIndex = lines[(headingIndex + 1)...].firstIndex(where: isTableRow),
            headerIndex + 1 < lines.count,
            isSeparatorRow(lines[headerIndex + 1])
        else {
            return []
        }

        var rows: [MarkdownTableRow] = []
        for line in lines[(headerIndex + 2)...] {
            guard isTableRow(line) else { break }
            let cells = parseTableCells(line)
            guard !cells.isEmpty else { continue }
            rows.append(MarkdownTableRow(cells: cells))
        }
        return rows
    }

    private func isTableRow(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("|")
    }

    private func isSeparatorRow(_ line: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "|:- ")
        return line.unicodeScalars.allSatisfy { allowed.contains($0) }
            && line.contains("---")
    }

    private func parseTableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private func statusSummary(for cells: ArraySlice<String>) -> String {
        let values = cells.map(normalize)
        let pending = values.filter { $0 == "pending" }.count
        let notTested = values.filter { $0 == "not tested" || $0 == "not run" }.count
        let failed = values.filter { $0.hasPrefix("fail") || $0.contains("failed") }.count
        let available = values.count - pending - notTested - failed

        var parts: [String] = []
        if available > 0 {
            parts.append("\(available) recorded")
        }
        if pending > 0 {
            parts.append("\(pending) pending")
        }
        if notTested > 0 {
            parts.append("\(notTested) not tested")
        }
        if failed > 0 {
            parts.append("\(failed) failed")
        }
        return parts.isEmpty ? "no cells" : parts.joined(separator: ", ")
    }

    private func graphicsStatusSummary(row: MarkdownTableRow) -> String {
        let submitted = row.cell(named: "submitted frame") ?? "unknown"
        let backing = row.cell(named: "backing") ?? "unknown"
        let failure = row.cell(named: "failure/fallback") ?? "unknown"
        return "submitted frame=\(submitted); backing=\(backing); failure/fallback=\(failure)"
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct MarkdownTableRow {
    let cells: [String]

    var firstCell: String {
        cells.first ?? "<unknown>"
    }

    func cell(named name: String) -> String? {
        let graphicsColumns = [
            "compositor", "display", "globals", "dmabuf", "surface feedback", "gbm", "egl",
            "explicit sync", "fifo", "commit timing", "metadata", "presentation feedback",
            "submitted frame", "release/reuse", "backing", "failure/fallback",
        ]
        guard let index = graphicsColumns.firstIndex(of: name), index < cells.count else {
            return nil
        }
        return cells[index]
    }
}
