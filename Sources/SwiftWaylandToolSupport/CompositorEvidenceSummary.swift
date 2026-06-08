import Foundation

public struct CompositorEvidenceSummarizer {
    public init() {
        // Stateless summarizer.
    }

    public func summarize(markdown: String) throws -> String {
        let mainRows = try MarkdownTable.rows(afterHeading: "## Matrix", in: markdown)
        let graphicsRows = try MarkdownTable.rows(
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

        let incompleteCells = CompositorEvidenceCompletenessVerifier()
            .incompleteEvidenceCells(markdown: markdown)
        lines.append("")
        lines.append("Incomplete evidence:")
        lines.append(contentsOf: incompleteEvidenceSummary(incompleteCells))

        return lines.joined(separator: "\n")
    }

    private func statusSummary(for cells: ArraySlice<String>) -> String {
        let values = cells.map(normalize)
        let pending = values.filter { $0 == "pending" }.count
        let notTested = values.filter { $0 == "not tested" || $0 == "not run" }.count
        let environmentSkips = values.filter { $0.contains("environment skip") }.count
        let manualGaps = values.filter { $0.contains("manual interaction required") }.count
        let failed = values.filter { $0.hasPrefix("fail") || $0.contains("failed") }.count
        let available = values.count - pending - notTested - environmentSkips - manualGaps - failed

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
        if environmentSkips > 0 {
            let label = summaryLabel(marker: "environment skip", count: environmentSkips)
            parts.append("\(environmentSkips) \(label)")
        }
        if manualGaps > 0 {
            let label = summaryLabel(marker: "manual interaction required", count: manualGaps)
            parts.append("\(manualGaps) \(label)")
        }
        if failed > 0 {
            parts.append("\(failed) failed")
        }
        return parts.isEmpty ? "no cells" : parts.joined(separator: ", ")
    }

    private func incompleteEvidenceSummary(
        _ cells: [CompositorEvidenceCompletenessVerifier.IncompleteEvidenceCell]
    ) -> [String] {
        guard !cells.isEmpty else {
            return ["- none"]
        }

        let markerOrder = [
            "pending",
            "not tested",
            "not run",
            "environment skip",
            "manual interaction required",
        ]
        let counts = Dictionary(grouping: cells, by: \.marker).mapValues(\.count)
        let countParts = markerOrder.compactMap { marker -> String? in
            guard let count = counts[marker], count > 0 else { return nil }
            return "\(count) \(summaryLabel(marker: marker, count: count))"
        }

        var lines = ["- \(countParts.joined(separator: ", "))"]
        lines.append(contentsOf: cells.prefix(8).map { "- \($0.description)" })
        let remainingCount = cells.count - min(cells.count, 8)
        if remainingCount > 0 {
            lines.append("- \(remainingCount) more incomplete evidence cells")
        }
        return lines
    }

    private func summaryLabel(marker: String, count: Int) -> String {
        switch marker {
        case "environment skip":
            count == 1 ? "environment skip" : "environment skips"
        case "manual interaction required":
            count == 1 ? "manual interaction gap" : "manual interaction gaps"
        case "not tested":
            "not tested"
        case "not run":
            "not run"
        default:
            marker
        }
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

public struct CompositorEvidenceCompletenessVerifier {
    public init() {
        // Stateless verifier.
    }

    public func verify(markdown: String) throws {
        let findings = incompleteEvidenceCells(markdown: markdown)
        guard findings.isEmpty else {
            let listedFindings = findings.prefix(12).map { "- \($0.description)" }
            let remainingCount = findings.count - listedFindings.count
            let remainingSuffix =
                remainingCount > 0 ? "\n- \(remainingCount) more incomplete evidence cells" : ""
            throw ToolError(
                """
                foundation evidence is incomplete; update docs/compositor-matrix.md
                or record exact environment skips before claiming foundation readiness

                Incomplete evidence cells:
                \(listedFindings.joined(separator: "\n"))\(remainingSuffix)
                """,
                exitCode: ToolExitCode.data
            )
        }
    }

    public func incompleteEvidenceCells(markdown: String) -> [IncompleteEvidenceCell] {
        MarkdownTable.allTables(in: markdown).flatMap { table in
            table.rows.flatMap { row in
                row.cells.enumerated().compactMap { index, value in
                    guard let marker = Self.incompleteMarker(in: value) else { return nil }
                    return IncompleteEvidenceCell(
                        section: table.section,
                        row: row.firstCell,
                        column: table.columnName(at: index),
                        value: value,
                        marker: marker)
                }
            }
        }
    }

    public struct IncompleteEvidenceCell: CustomStringConvertible, Equatable {
        public let section: String
        public let row: String
        public let column: String
        public let value: String
        public let marker: String

        public var description: String {
            "\(section): \(row) / \(column) contains \(marker): \(value)"
        }
    }

    private static func incompleteMarker(in value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for marker in [
            "pending",
            "not tested",
            "not run",
            "environment skip",
            "manual interaction required",
        ] where normalized.contains(marker) {
            return marker
        }
        return nil
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

private struct MarkdownTable {
    let section: String
    let columns: [String]
    let rows: [MarkdownTableRow]

    static func rows(afterHeading heading: String, in markdown: String) throws -> [MarkdownTableRow]
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

        return tableRows(startingAt: headerIndex + 2, lines: lines)
    }

    static func allTables(in markdown: String) -> [MarkdownTable] {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(
            String.init)
        var tables: [MarkdownTable] = []
        var section = "Document"
        var index = 0
        var inCodeFence = false

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inCodeFence.toggle()
                index += 1
                continue
            }
            if !inCodeFence, trimmed.hasPrefix("#") {
                section = trimmed.trimmingCharacters(in: .whitespaces)
                index += 1
                continue
            }
            guard !inCodeFence, isTableRow(line), index + 1 < lines.count,
                isSeparatorRow(lines[index + 1])
            else {
                index += 1
                continue
            }

            let columns = parseTableCells(line)
            let rows = tableRows(startingAt: index + 2, lines: lines)
            tables.append(MarkdownTable(section: section, columns: columns, rows: rows))
            index += rows.count + 2
        }

        return tables
    }

    func columnName(at index: Int) -> String {
        guard index < columns.count else { return "column \(index + 1)" }
        return columns[index]
    }

    private static func tableRows(startingAt startIndex: Int, lines: [String])
        -> [MarkdownTableRow]
    {
        var rows: [MarkdownTableRow] = []
        for line in lines[startIndex...] {
            guard isTableRow(line) else { break }
            guard !isSeparatorRow(line) else { continue }
            let cells = parseTableCells(line)
            guard !cells.isEmpty else { continue }
            rows.append(MarkdownTableRow(cells: cells))
        }
        return rows
    }

    private static func isTableRow(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("|")
    }

    private static func isSeparatorRow(_ line: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "|:- ")
        return line.unicodeScalars.allSatisfy { allowed.contains($0) }
            && line.contains("---")
    }

    private static func parseTableCells(_ line: String) -> [String] {
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
}
