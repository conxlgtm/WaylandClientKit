import Foundation

public struct CoverageSummarizer {
    public let repository: Repository
    public let fileSystem: FileSystem
    public let buildRoot: URL
    public let productsDirectory: URL

    public init(
        repository: Repository, buildRoot: URL? = nil, productsDirectory: URL? = nil,
        fileSystem: FileSystem = LocalFileSystem()
    ) {
        self.repository = repository
        self.buildRoot = buildRoot ?? repository.url(".build")
        self.productsDirectory = productsDirectory ?? self.buildRoot.appendingPathComponent("debug")
        self.fileSystem = fileSystem
    }

    public func summarize(explicitPath: String?) throws -> String {
        let url: URL
        if let explicitPath, !explicitPath.isEmpty {
            url =
                URL(fileURLWithPath: explicitPath, relativeTo: repository.root).standardizedFileURL
        } else {
            let coverageRoot = productsDirectory.appendingPathComponent("codecov")
                .resolvingSymlinksInPath()
            guard coverageRoot.path.hasPrefix(buildRoot.resolvingSymlinksInPath().path + "/") else {
                throw ToolError(
                    "Coverage is outside selected scratch tree", exitCode: ToolExitCode.data)
            }
            url = coverageRoot.appendingPathComponent("all-targets.json")
        }
        guard fileSystem.exists(url) else {
            throw ToolError(
                "Coverage JSON was not found at \(url.path)", exitCode: ToolExitCode.data)
        }
        return markdown(for: try collectCoverage(url))
    }

    private func collectCoverage(_ url: URL) throws -> [String: CoverageAggregate] {
        let object = try JSONSerialization.jsonObject(with: fileSystem.readData(url))
        guard let object = object as? [String: Any],
            let data = object["data"] as? [[String: Any]]
        else {
            throw ToolError(
                "Coverage JSON has no data array: \(url.path)", exitCode: ToolExitCode.data)
        }
        let sourcesRoot = repository.url("Sources").path
        var modules: [String: CoverageAggregate] = [:]
        var filenames = Set<String>()
        for entry in data {
            for file in entry["files"] as? [[String: Any]] ?? [] {
                guard let filename = file["filename"] as? String,
                    filename.hasPrefix(sourcesRoot + "/"),
                    let module = filename.dropFirst(sourcesRoot.count + 1)
                        .split(separator: "/").first.map(String.init),
                    let summary = file["summary"] as? [String: Any],
                    let lines = summary["lines"] as? [String: Any],
                    let functions = summary["functions"] as? [String: Any]
                else { continue }
                guard filenames.insert(filename).inserted else {
                    throw ToolError(
                        "Repeated coverage for \(filename); export all objects together with LLVM",
                        exitCode: ToolExitCode.data)
                }
                modules[module, default: CoverageAggregate()] += CoverageAggregate(
                    linesCount: intValue(lines["count"]), linesCovered: intValue(lines["covered"]),
                    functionsCount: intValue(functions["count"]),
                    functionsCovered: intValue(functions["covered"]))
            }
        }
        return modules
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
            lines.append("| `\(module)` | \(linePercent)% | \(functionPercent)% |")
        }
        let totalLinePercent = percent(total.linesCovered, total.linesCount)
        let totalFunctionPercent = percent(total.functionsCovered, total.functionsCount)
        lines.append("| **Source total** | \(totalLinePercent)% | \(totalFunctionPercent)% |")
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
