import Foundation

public struct CoverageSummarizer {
    public let repository: Repository
    public let fileSystem: FileSystem

    public init(repository: Repository, fileSystem: FileSystem = LocalFileSystem()) {
        self.repository = repository
        self.fileSystem = fileSystem
    }

    public func summarize(explicitPath: String?) throws -> String {
        let coverageURL: URL
        if let explicitPath, !explicitPath.isEmpty {
            coverageURL =
                URL(fileURLWithPath: explicitPath, relativeTo: repository.root).standardizedFileURL
        } else {
            guard let discovered = try latestCoverageJSON() else {
                throw ToolError(
                    "Coverage JSON was not found: .build/*/debug/codecov/WaylandClientKit.json",
                    exitCode: ToolExitCode.data
                )
            }
            coverageURL = discovered
        }

        guard fileSystem.exists(coverageURL) else {
            throw ToolError(
                "Coverage JSON was not found: \(coverageURL.path)", exitCode: ToolExitCode.data)
        }

        let object = try JSONHelpers.loadObject(from: coverageURL)
        guard let data = object["data"] as? [[String: Any]] else {
            throw ToolError("coverage JSON has no data array", exitCode: ToolExitCode.data)
        }

        var modules: [String: CoverageAggregate] = [:]
        let sourcesRoot = repository.url("Sources").path
        for dataEntry in data {
            guard let files = dataEntry["files"] as? [[String: Any]] else { continue }
            for file in files {
                guard
                    let filename = file["filename"] as? String,
                    filename.hasPrefix(sourcesRoot + "/")
                else {
                    continue
                }
                let relative = String(filename.dropFirst(sourcesRoot.count + 1))
                guard let module = relative.split(separator: "/").first.map(String.init) else {
                    continue
                }
                guard
                    let summary = file["summary"] as? [String: Any],
                    let lines = summary["lines"] as? [String: Any],
                    let functions = summary["functions"] as? [String: Any]
                else {
                    continue
                }
                var aggregate = modules[module, default: CoverageAggregate()]
                aggregate.linesCount += intValue(lines["count"])
                aggregate.linesCovered += intValue(lines["covered"])
                aggregate.functionsCount += intValue(functions["count"])
                aggregate.functionsCovered += intValue(functions["covered"])
                modules[module] = aggregate
            }
        }

        return markdown(for: modules)
    }

    private func latestCoverageJSON() throws -> URL? {
        let build = repository.url(".build")
        let candidates = try fileSystem.walk(build, includingDirectories: false)
            .filter { $0.path.hasSuffix("/debug/codecov/WaylandClientKit.json") }
            .sorted { lhs, rhs in
                modificationDate(lhs) > modificationDate(rhs)
            }
        return candidates.first
    }

    private func modificationDate(_ url: URL) -> Date {
        do {
            return try url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate ?? .distantPast
        } catch {
            return .distantPast
        }
    }

    private func markdown(for modules: [String: CoverageAggregate]) -> String {
        var lines = [
            "| Module | Line coverage | Function coverage |",
            "| --- | ---: | ---: |",
        ]
        var total = CoverageAggregate()
        for module in modules.keys.sorted() {
            guard let aggregate = modules[module] else { continue }
            total += aggregate
            let linePercent = percent(aggregate.linesCovered, aggregate.linesCount)
            let functionPercent = percent(aggregate.functionsCovered, aggregate.functionsCount)
            lines.append(
                "| `\(module)` | \(linePercent)% | \(functionPercent)% |"
            )
        }
        let totalLinePercent = percent(total.linesCovered, total.linesCount)
        let totalFunctionPercent = percent(total.functionsCovered, total.functionsCount)
        lines.append(
            "| **Source total** | \(totalLinePercent)% | \(totalFunctionPercent)% |"
        )
        return lines.joined(separator: "\n")
    }

    private func intValue(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? String { return Int(value) ?? 0 }
        return 0
    }

    private func percent(_ covered: Int, _ count: Int) -> String {
        guard count > 0 else { return "0.00" }
        return String(format: "%.2f", Double(covered) * 100.0 / Double(count))
    }
}

private struct CoverageAggregate {
    var linesCount = 0
    var linesCovered = 0
    var functionsCount = 0
    var functionsCovered = 0

    static func += (lhs: inout CoverageAggregate, rhs: CoverageAggregate) {
        lhs.linesCount += rhs.linesCount
        lhs.linesCovered += rhs.linesCovered
        lhs.functionsCount += rhs.functionsCount
        lhs.functionsCovered += rhs.functionsCovered
    }
}
