import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct CoverageAggregationTests {
    @Test
    func summarizesCombinedLLVMReportOnlyFromSelectedProducts() throws {
        let root = try temporaryRoot()
        defer { removeRoot(root) }
        let scratch = root.appendingPathComponent("scratch")
        let products = scratch.appendingPathComponent("out/Products/Debug-linux-aarch64")
        let files = [
            record(root, "Sources/Fixture/Shared.swift", lines: [4, 2], functions: [2, 1]),
            record(root, "Sources/Fixture/Extra.swift", lines: [2, 2], functions: [1, 1]),
            record(root, "Sources/Shim/Bridge.c", lines: [1, 0], functions: [1, 0]),
            record(root, "SourcesOther/Foreign.swift", lines: [100, 0], functions: [100, 0]),
            record(root, "Tests/FixtureTests.swift", lines: [100, 0], functions: [100, 0]),
        ]
        try writeJSON(files, to: products.appendingPathComponent("codecov/all-targets.json"))
        let stale = [
            record(root, "Sources/Fixture/Shared.swift", lines: [4, 0], functions: [2, 0])
        ]
        for path in [
            ".build/debug/codecov/all-targets.json",
            "scratch/debug/codecov/all-targets.json",
            "scratch/out/Products/Debug-linux-aarch64/codecov/OldTarget.json",
        ] {
            try writeJSON(stale, to: root.appendingPathComponent(path))
        }
        let report = try CoverageSummarizer(
            repository: Repository(root: root), buildRoot: scratch, productsDirectory: products
        ).summarize(explicitPath: nil)
        #expect(report.contains("| `Fixture` | 66.67% | 66.67% |"))
        #expect(report.contains("| `Shim` | 0.00% | 0.00% |"))
        #expect(report.contains("| **Source total** | 57.14% | 50.00% |"))
        #expect(!report.contains("Foreign"))
    }

    @Test
    func rejectsDuplicateSourceSummariesInsteadOfDoubleCounting() throws {
        let root = try temporaryRoot()
        defer { removeRoot(root) }
        let file = record(root, "Sources/Fixture/Shared.swift", lines: [4, 2], functions: [2, 1])
        let json = root.appendingPathComponent("combined.json")
        try writeJSON([file, file], to: json)
        #expect(throws: ToolError.self) {
            try CoverageSummarizer(repository: Repository(root: root))
                .summarize(explicitPath: json.path)
        }
    }

    @Test
    func missingSelectedReportDoesNotFallBackToDefaultScratchTree() throws {
        let root = try temporaryRoot()
        defer { removeRoot(root) }
        try writeJSON(
            [record(root, "Sources/Fixture/Shared.swift", lines: [4, 4], functions: [2, 2])],
            to: root.appendingPathComponent(".build/debug/codecov/all-targets.json"))
        #expect(throws: ToolError.self) {
            try CoverageSummarizer(
                repository: Repository(root: root),
                buildRoot: root.appendingPathComponent("scratch")
            ).summarize(explicitPath: nil)
        }
    }

    private func record(
        _ root: URL, _ path: String, lines: [Int], functions: [Int]
    ) -> [String: Any] {
        [
            "filename": root.appendingPathComponent(path).path,
            "summary": [
                "lines": ["count": lines[0], "covered": lines[1]],
                "functions": ["count": functions[0], "covered": functions[1]],
            ],
        ]
    }

    private func writeJSON(_ files: [[String: Any]], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: ["data": [["files": files]]]).write(to: url)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func removeRoot(_ root: URL) {
        do {
            try FileManager.default.removeItem(at: root)
        } catch {
            Issue.record("Fixture cleanup failed: \(error)")
        }
    }
}
