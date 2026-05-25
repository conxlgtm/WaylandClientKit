import Testing
import WaylandExampleSupport

@Suite
struct ExampleRunOptionsTests {
    @Test
    func doubleDashStopsOptionParsing() throws {
        let options = try ExampleRunOptions.parse([
            "--duration-seconds",
            "5",
            "--print-summary",
            "--",
            "--unknown-launcher-argument",
        ][...])

        #expect(options == ExampleRunOptions(durationSeconds: 5, printSummary: true))
    }

    @Test
    func unknownArgumentBeforeDoubleDashThrows() {
        #expect(throws: ExampleRunOptionError.unknownArgument("--unknown")) {
            try ExampleRunOptions.parse(["--unknown", "--"][...])
        }
    }
}
