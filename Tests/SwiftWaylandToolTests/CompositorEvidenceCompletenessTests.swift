import SwiftWaylandToolSupport
import Testing

@Suite
struct CompositorEvidenceCompletenessTests {
    @Test
    func checksFrameworkHostRowsOutsideSynthesizedSummary() throws {
        let markdown = """
            # Compositor Matrix

            ## Matrix

            | Compositor | Version | Protocol facts | Smoke |
            | ---------- | ------- | -------------- | ----- |
            | Weston headless | 15.0.0 | facts recorded | pass |

            ## Graphics Preview Evidence

            \(tableLine(graphicsColumns))
            \(tableLine(Array(repeating: "----------", count: graphicsColumns.count)))
            \(tableLine(completeGraphicsRow))

            ## Framework Host Evidence

            | Compositor | Pointer capture | Text input |
            | ---------- | --------------- | ---------- |
            | Weston headless | pending | pass |
            """

        do {
            try CompositorEvidenceCompletenessVerifier().verify(markdown: markdown)
            Issue.record("expected incomplete framework-host evidence to fail")
        } catch let error as ToolError {
            #expect(error.message.contains("## Framework Host Evidence"))
            #expect(error.message.contains("Weston headless / Pointer capture"))
            #expect(error.message.contains("pending"))
        }
    }

    @Test
    func acceptsCompleteEvidenceRows() throws {
        let markdown = """
            # Compositor Matrix

            ## Framework Host Evidence

            | Compositor | Pointer capture | Text input |
            | ---------- | --------------- | ---------- |
            | Weston headless | skipped(zwp_pointer_constraints_v1 unavailable) | pass |
            """

        let findings = CompositorEvidenceCompletenessVerifier()
            .incompleteEvidenceCells(markdown: markdown)

        #expect(findings.isEmpty)
    }

    @Test
    func flagsExplicitEnvironmentSkipsAndManualEvidenceGaps() throws {
        let markdown = """
            # Compositor Matrix

            ## Framework Host Evidence

            | Compositor | Pointer capture | Text input |
            | ---------- | --------------- | ---------- |
            | GNOME / Mutter | environment skip(GNOME session unavailable) | pass |
            | KDE / KWin | manual interaction required(lock/confine motion) | pass |
            """

        let findings = CompositorEvidenceCompletenessVerifier()
            .incompleteEvidenceCells(markdown: markdown)

        #expect(findings.count == 2)
        #expect(findings[0].marker == "environment skip")
        #expect(findings[0].row == "GNOME / Mutter")
        #expect(findings[1].marker == "manual interaction required")
        #expect(findings[1].row == "KDE / KWin")
    }

    private var graphicsColumns: [String] {
        [
            "Compositor", "Display", "Globals", "dmabuf", "surface feedback", "GBM", "EGL",
            "explicit sync", "FIFO", "commit timing", "metadata", "presentation feedback",
            "submitted frame", "release/reuse", "backing", "failure/fallback",
        ]
    }

    private var completeGraphicsRow: [String] {
        [
            "Weston headless", "socket", "dmabuf unavailable", "unavailable",
            "fallback(dmabufUnavailable)", "fallback(dmabufUnavailable)",
            "fallback(dmabufUnavailable)", "unavailable", "advertised", "advertised",
            "unavailable", "advertised", "success", "software fallback",
            "software fallback(dmabufUnavailable)", "none",
        ]
    }

    private func tableLine(_ cells: [String]) -> String {
        "| \(cells.joined(separator: " | ")) |"
    }
}
