import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct CoverageProfileAccumulationTests {
    @Test
    func preservesCountersAcrossSwiftPMDirectoryReplacementAndResetsNewRuns() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                Issue.record("Fixture cleanup failed: \(error)")
            }
        }
        let products = root.appendingPathComponent("out/Products/Debug-linux-x86_64")
        let managed = products.appendingPathComponent("codecov")
        let artifacts = try SwiftBuildArtifacts(buildRoot: root, productsDirectory: products)
        let repository = Repository(root: root)
        let swift = SwiftToolchain()

        try writeProfile("alpha\n0\n1\n2\n\n", to: managed)
        try await artifacts.accumulateCoverage(swift: swift, repository: repository)
        // Simulate SwiftPM replacing the coverage directory between test filters.
        try FileManager.default.removeItem(at: managed)
        try writeProfile("alpha\n0\n1\n3\n\nbeta\n0\n1\n7\n\n", to: managed)
        try await artifacts.accumulateCoverage(swift: swift, repository: repository)
        #expect(
            try await counters(swift: swift, repository: repository, products: products)
                == ["alpha": 5, "beta": 7])

        try artifacts.resetCoverage()
        try writeProfile("beta\n0\n1\n2\n\n", to: managed)
        try await artifacts.accumulateCoverage(swift: swift, repository: repository)
        #expect(
            try await counters(swift: swift, repository: repository, products: products)
                == ["beta": 2])
    }

    private func writeProfile(_ text: String, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(
            to: directory.appendingPathComponent("run.profraw"), atomically: true, encoding: .utf8)
    }

    private func counters(
        swift: SwiftToolchain, repository: Repository, products: URL
    ) async throws -> [String: Int] {
        let tool = URL(
            fileURLWithPath: try swift.swiftCompilerExecutable(
                environment: swift.runner.environment)
        ).deletingLastPathComponent().appendingPathComponent("llvm-profdata")
        let text = products.appendingPathComponent("counters.txt")
        try await swift.runSwiftTool(
            tool.path,
            [
                "merge", "-text", products.appendingPathComponent("wck-coverage.profdata").path,
                "-o", text.path,
            ],
            repository: repository)
        let fields = try String(contentsOf: text, encoding: .utf8).split(separator: "\n")
            .filter { !$0.hasPrefix("#") }
        guard fields.count.isMultiple(of: 4) else {
            throw ToolError("Malformed LLVM counter records")
        }
        var result: [String: Int] = [:]
        for index in stride(from: 0, to: fields.count, by: 4) {
            guard fields[index + 2] == "1", let count = Int(fields[index + 3]) else {
                throw ToolError("Expected one function counter per LLVM fixture record")
            }
            result[String(fields[index])] = count
        }
        return result
    }
}
