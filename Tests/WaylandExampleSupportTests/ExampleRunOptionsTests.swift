import Testing
import WaylandExampleSupport

@Suite
struct ExampleRunOptionsTests {
    @Test
    func doubleDashStopsOptionParsing() throws {
        let options = try ExampleRunOptions.parse(
            [
                "--duration-seconds",
                "5",
                "--print-summary",
                "--",
                "--unknown-launcher-argument",
            ][...]
        )

        #expect(options == ExampleRunOptions(durationSeconds: 5, printSummary: true))
    }

    @Test
    func unknownArgumentBeforeDoubleDashThrows() {
        #expect(throws: ExampleRunOptionError.unknownArgument("--unknown")) {
            try ExampleRunOptions.parse(["--unknown", "--"][...])
        }
    }

    @Test
    func graphicsPreviewOptionsAreParsed() throws {
        let options = try ExampleRunOptions.parse(
            [
                "--sync",
                "prefer-explicit",
                "--pacing",
                "fifo",
                "--metadata",
                "prefer",
                "--content-type",
                "game",
                "--presentation-hint",
                "async",
            ][...]
        )

        #expect(options.synchronization == "prefer-explicit")
        #expect(options.pacing == "fifo")
        #expect(options.metadata == "prefer")
        #expect(options.contentType == "game")
        #expect(options.presentationHint == "async")
    }
}
