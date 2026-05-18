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
        let command = try SmokeArguments.parse([
            "--require-linux-dmabuf",
            "--require-syncobj",
            "--require-fifo",
            "--require-commit-timing",
        ])

        #expect(
            command
                == .run(
                    SmokeConfiguration(
                        requestedOptionalProtocols: [
                            .linuxDmabuf,
                            .linuxDrmSyncobj,
                            .fifo,
                            .commitTiming,
                        ]
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

    @Test(arguments: [
        (
            SmokeOptionalProtocol.linuxDrmSyncobj,
            "Skipping syncobj live test: compositor did not advertise "
                + "wp_linux_drm_syncobj_manager_v1."
        ),
        (
            SmokeOptionalProtocol.fifo,
            "Skipping FIFO live test: compositor did not advertise "
                + "wp_fifo_manager_v1."
        ),
        (
            SmokeOptionalProtocol.commitTiming,
            "Skipping commit-timing live test: compositor did not advertise "
                + "wp_commit_timing_manager_v1."
        ),
    ])
    func submitProtocolSkipMessagesNameExactInterface(
        optionalProtocol: SmokeOptionalProtocol,
        expectedMessage: String
    ) {
        #expect(SmokeResult.skippedOptionalProtocol(optionalProtocol).description == expectedMessage)
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
