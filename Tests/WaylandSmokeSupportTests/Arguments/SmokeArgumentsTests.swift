import Testing
import WaylandSmokeSupport

@Suite
struct SmokeArgumentsTests {
    @Test
    func emptyArgumentsRunDefaultConfiguration() throws {
        let command = try SmokeArguments.parse([])

        #expect(command == .run(SmokeConfiguration()))
    }

    @Test
    func helpArgumentsReturnHelpCommand() throws {
        #expect(try SmokeArguments.parse(["--help"]) == .help)
        #expect(try SmokeArguments.parse(["-h"]) == .help)
    }

    @Test
    func timeoutArgumentsOverrideConfiguration() throws {
        let command = try SmokeArguments.parse([
            "--timeout-milliseconds",
            "2500",
            "--post-commit-pump-milliseconds",
            "25",
        ])

        #expect(
            command
                == .run(
                    try SmokeConfiguration(
                        timeoutMilliseconds: 2_500,
                        postCommitPumpMilliseconds: 25
                    )
                )
        )
    }

    @Test
    func linuxDmabufRequirementIsRecordedInConfiguration() throws {
        let command = try SmokeArguments.parse(["--require-linux-dmabuf"])

        #expect(
            command
                == .run(
                    SmokeConfiguration(
                        requestedOptionalProtocols: [.linuxDmabuf]
                    )
                )
        )
    }

    @Test
    func linuxDmabufSkipMessageNamesExactInterface() {
        let result = SmokeResult.skippedOptionalProtocol(.linuxDmabuf)

        #expect(
            result.description
                == "Skipping linux-dmabuf live test: compositor did not advertise "
                + "zwp_linux_dmabuf_v1."
        )
    }

    @Test
    func doubleDashIsRejectedBecauseSmokeHasNoPositionals() {
        #expect(throws: SmokeArgumentError.unsupportedEndOfOptionsMarker) {
            try SmokeArguments.parse(["--"])
        }
    }

    @Test
    func missingArgumentValueThrows() {
        #expect(throws: SmokeArgumentError.missingValue("--timeout-milliseconds")) {
            try SmokeArguments.parse(["--timeout-milliseconds"])
        }
    }

    @Test
    func invalidArgumentValueThrows() {
        #expect(
            throws: SmokeArgumentError.invalidValue(
                argument: "--timeout-milliseconds",
                value: "nope"
            )
        ) {
            try SmokeArguments.parse(["--timeout-milliseconds", "nope"])
        }
    }

    @Test
    func unknownArgumentThrows() {
        #expect(throws: SmokeArgumentError.unknownArgument("--bad")) {
            try SmokeArguments.parse(["--bad"])
        }
    }

    @Test
    func smokeConfigurationRejectsNonPositiveTimeout() {
        #expect(
            throws: SmokeConfigurationError.nonPositiveMilliseconds(
                field: .timeoutMilliseconds,
                value: 0
            )
        ) {
            try SmokeConfiguration(timeoutMilliseconds: 0, postCommitPumpMilliseconds: 16)
        }
    }

    @Test
    func smokeConfigurationRejectsNonPositivePostCommitPump() {
        #expect(
            throws: SmokeConfigurationError.nonPositiveMilliseconds(
                field: .postCommitPumpMilliseconds,
                value: -1
            )
        ) {
            try SmokeConfiguration(timeoutMilliseconds: 1, postCommitPumpMilliseconds: -1)
        }
    }
}
