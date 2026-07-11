import Foundation
import Testing

struct SmokeCommandConvergenceTests {
    @Test
    func gpuPreviewSmokeRunsTheExamplesPackageTarget() throws {
        let source = try String(
            contentsOf: repositoryRoot()
                .appendingPathComponent("Sources/WaylandClientKitTool/main.swift"),
            encoding: .utf8
        )
        let start = try #require(source.range(of: "struct GPUPreview: ToolCommand"))
        let end = try #require(source.range(of: "struct Headless: ToolCommand"))
        let commandBody = String(source[start.lowerBound..<end.lowerBound])

        #expect(commandBody.contains(#""run", "--package-path", "Examples""#))
        #expect(commandBody.contains("GPUPreviewSmokeClient"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
