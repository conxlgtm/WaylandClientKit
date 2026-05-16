import Glibc
import Testing

@testable import WaylandRaw

@Suite
struct RawLinuxDmabufFeedbackStateTests {
    @Test
    func buildsSurfaceScopedFeedbackSnapshot() throws {
        let entries = [
            RawLinuxDmabufFormatModifier(format: 875_713_112, modifier: 0),
            RawLinuxDmabufFormatModifier(format: 875_713_089, modifier: UInt64.max),
        ]
        var state = RawLinuxDmabufFeedbackState()

        state.replaceFormatTable(entries)
        try state.setMainDevice(bytes: [0x01, 0x02, 0x03, 0x04], scope: .surface(surfaceID: 77))
        try state.setCurrentTrancheTargetDevice(
            bytes: [0x05, 0x06, 0x07, 0x08],
            scope: .surface(surfaceID: 77)
        )
        try state.appendCurrentTrancheFormats(indices: [1, 0], scope: .surface(surfaceID: 77))
        try state.setCurrentTrancheFlags(
            RawLinuxDmabufTrancheFlags.scanout.rawValue | 0x8000_0000,
            scope: .surface(surfaceID: 77)
        )
        try state.finishCurrentTranche(scope: .surface(surfaceID: 77))

        let snapshot = try state.finish(scope: .surface(surfaceID: 77))

        #expect(snapshot.scope == .surface(surfaceID: 77))
        #expect(snapshot.mainDevice == RawLinuxDmabufDevice(bytes: [0x01, 0x02, 0x03, 0x04]))
        #expect(snapshot.formatTable == entries)
        #expect(snapshot.tranches.count == 1)
        #expect(
            snapshot.tranches[0].targetDevice
                == RawLinuxDmabufDevice(bytes: [0x05, 0x06, 0x07, 0x08])
        )
        #expect(snapshot.tranches[0].formats == [entries[1], entries[0]])
        #expect(snapshot.tranches[0].flags.contains(.scanout))
        #expect(snapshot.tranches[0].flags.unknownRawValue == 0x8000_0000)
        #expect(snapshot.tranches[0].flags.hasUnknownBits)
        #expect(snapshot.tranches[0].formatModifiers(for: entries[1].format) == [entries[1]])
    }

    @Test
    func resentFeedbackReplacesPreviousSnapshot() throws {
        let firstEntry = RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        let replacementEntry = RawLinuxDmabufFormatModifier(format: 3, modifier: 4)
        var state = RawLinuxDmabufFeedbackState()

        state.replaceFormatTable([firstEntry])
        try state.setMainDevice(bytes: [0x01], scope: .defaultFeedback)
        try state.setCurrentTrancheTargetDevice(bytes: [0x02], scope: .defaultFeedback)
        try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)
        try state.appendCurrentTrancheFormats(indices: [0], scope: .defaultFeedback)
        try state.finishCurrentTranche(scope: .defaultFeedback)
        _ = try state.finish(scope: .defaultFeedback)

        state.replaceFormatTable([replacementEntry])
        try state.setMainDevice(bytes: [0x03], scope: .defaultFeedback)
        try state.setCurrentTrancheTargetDevice(bytes: [0x04], scope: .defaultFeedback)
        try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)
        try state.appendCurrentTrancheFormats(indices: [0], scope: .defaultFeedback)
        try state.finishCurrentTranche(scope: .defaultFeedback)

        let snapshot = try state.finish(scope: .defaultFeedback)

        #expect(snapshot.mainDevice == RawLinuxDmabufDevice(bytes: [0x03]))
        #expect(snapshot.formatTable == [replacementEntry])
        #expect(snapshot.tranches.count == 1)
        #expect(snapshot.tranches[0].targetDevice == RawLinuxDmabufDevice(bytes: [0x04]))
        #expect(snapshot.tranches[0].formats == [replacementEntry])
    }

    @Test
    func doneAfterCompletedBatchStartsFreshBatch() throws {
        let entry = RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        var state = RawLinuxDmabufFeedbackState()

        state.replaceFormatTable([entry])
        try state.setMainDevice(bytes: [0x01], scope: .defaultFeedback)
        try state.setCurrentTrancheTargetDevice(bytes: [0x02], scope: .defaultFeedback)
        try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)
        try state.appendCurrentTrancheFormats(indices: [0], scope: .defaultFeedback)
        try state.finishCurrentTranche(scope: .defaultFeedback)
        _ = try state.finish(scope: .defaultFeedback)

        #expect(
            throws: malformedFeedback(
                event: "done",
                field: "main_device",
                discardedStaleState: false
            )
        ) {
            _ = try state.finish(scope: .defaultFeedback)
        }
    }

    @Test
    func doneWithoutMainDeviceReportsFailureAndDoesNotPublishSnapshot() throws {
        var state = RawLinuxDmabufFeedbackState()
        state.replaceFormatTable([
            RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        ])
        try state.setCurrentTrancheTargetDevice(bytes: [0x02], scope: .defaultFeedback)
        try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)
        try state.appendCurrentTrancheFormats(indices: [0], scope: .defaultFeedback)
        try state.finishCurrentTranche(scope: .defaultFeedback)

        #expect(
            throws: malformedFeedback(
                event: "done",
                field: "main_device"
            )
        ) {
            _ = try state.finish(scope: .defaultFeedback)
        }
    }

    @Test
    func trancheDoneWithoutTargetDeviceReportsFailure() throws {
        var state = RawLinuxDmabufFeedbackState()
        state.replaceFormatTable([
            RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        ])
        try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)
        try state.appendCurrentTrancheFormats(indices: [0], scope: .defaultFeedback)

        #expect(
            throws: malformedFeedback(
                event: "tranche_done",
                field: "tranche_target_device"
            )
        ) {
            try state.finishCurrentTranche(scope: .defaultFeedback)
        }
    }

    @Test
    func trancheDoneWithoutFormatsReportsFailure() throws {
        var state = RawLinuxDmabufFeedbackState()
        state.replaceFormatTable([
            RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        ])
        try state.setCurrentTrancheTargetDevice(bytes: [0x02], scope: .defaultFeedback)
        try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)

        #expect(
            throws: malformedFeedback(
                event: "tranche_done",
                field: "tranche_formats"
            )
        ) {
            try state.finishCurrentTranche(scope: .defaultFeedback)
        }
    }

    @Test
    func invalidFormatTableSuppressesDoneSnapshot() throws {
        var state = RawLinuxDmabufFeedbackState()
        state.replaceFormatTable([
            RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        ])
        try state.setMainDevice(bytes: [0x01], scope: .defaultFeedback)
        try state.setCurrentTrancheTargetDevice(bytes: [0x02], scope: .defaultFeedback)
        try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)
        try state.appendCurrentTrancheFormats(indices: [0], scope: .defaultFeedback)
        try state.finishCurrentTranche(scope: .defaultFeedback)
        _ = try state.finish(scope: .defaultFeedback)

        _ = state.invalidateFeedback(
            scope: .defaultFeedback,
            event: "format_table",
            field: "size",
            rawValue: 15
        )

        #expect(
            throws: malformedFeedback(
                event: "format_table",
                field: "size",
                rawValue: 15
            )
        ) {
            _ = try state.finish(scope: .defaultFeedback)
        }
    }

    @Test
    func doneWithUnfinishedTrancheReportsFailure() throws {
        var state = RawLinuxDmabufFeedbackState()
        state.replaceFormatTable([
            RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        ])
        try state.setMainDevice(bytes: [0x01], scope: .defaultFeedback)
        try state.setCurrentTrancheTargetDevice(bytes: [0x02], scope: .defaultFeedback)
        try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)
        try state.appendCurrentTrancheFormats(indices: [0], scope: .defaultFeedback)

        #expect(
            throws: malformedFeedback(
                event: "done",
                field: "tranche_done"
            )
        ) {
            _ = try state.finish(scope: .defaultFeedback)
        }
    }

    @Test
    func rejectsFormatIndexOutsideCurrentTable() throws {
        var state = RawLinuxDmabufFeedbackState()
        state.replaceFormatTable([
            RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        ])

        do {
            try state.appendCurrentTrancheFormats(indices: [1], scope: .defaultFeedback)
            Issue.record("Expected invalid dmabuf format table index to throw")
        } catch RuntimeError.invalidDmabufFormatTableIndex(let index, let entryCount) {
            #expect(index == 1)
            #expect(entryCount == 1)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite
struct RawLinuxDmabufFeedbackDuplicateEventTests {
    @Test
    func duplicateMainDeviceInvalidatesFeedback() throws {
        var state = RawLinuxDmabufFeedbackState()

        try state.setMainDevice(bytes: [0x01], scope: .defaultFeedback)

        #expect(
            throws: malformedFeedback(event: "main_device", field: "main_device")
        ) {
            try state.setMainDevice(bytes: [0x02], scope: .defaultFeedback)
        }
    }

    @Test
    func duplicateTrancheTargetDeviceInvalidatesFeedback() throws {
        var state = RawLinuxDmabufFeedbackState()

        try state.setCurrentTrancheTargetDevice(bytes: [0x01], scope: .defaultFeedback)

        #expect(
            throws: malformedFeedback(
                event: "tranche_target_device",
                field: "tranche_target_device"
            )
        ) {
            try state.setCurrentTrancheTargetDevice(bytes: [0x02], scope: .defaultFeedback)
        }
    }

    @Test
    func duplicateTrancheFlagsInvalidatesFeedback() throws {
        var state = RawLinuxDmabufFeedbackState()

        try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)

        #expect(
            throws: malformedFeedback(event: "tranche_flags", field: "tranche_flags")
        ) {
            try state.setCurrentTrancheFlags(
                RawLinuxDmabufTrancheFlags.scanout.rawValue,
                scope: .defaultFeedback
            )
        }
    }

    @Test
    func duplicateFormatWithinTrancheInvalidatesFeedback() {
        var state = RawLinuxDmabufFeedbackState()
        state.replaceFormatTable([
            RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        ])

        #expect(
            throws: malformedFeedback(
                event: "tranche_formats",
                field: "formats",
                index: 1,
                rawValue: 0
            )
        ) {
            try state.appendCurrentTrancheFormats(indices: [0, 0], scope: .defaultFeedback)
        }
    }

    @Test
    func duplicateFormatAcrossSameDeviceAndFlagsInvalidatesFeedback() throws {
        let format = RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        var state = RawLinuxDmabufFeedbackState()
        state.replaceFormatTable([format])
        try state.setMainDevice(bytes: [0x01], scope: .defaultFeedback)
        try state.setCurrentTrancheTargetDevice(bytes: [0x02], scope: .defaultFeedback)
        try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)
        try state.appendCurrentTrancheFormats(indices: [0], scope: .defaultFeedback)
        try state.finishCurrentTranche(scope: .defaultFeedback)

        try state.setCurrentTrancheTargetDevice(bytes: [0x02], scope: .defaultFeedback)
        try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)
        try state.appendCurrentTrancheFormats(indices: [0], scope: .defaultFeedback)

        #expect(
            throws: malformedFeedback(
                event: "tranche_done",
                field: "tranche_formats",
                index: 0,
                rawValue: UInt64(format.format)
            )
        ) {
            try state.finishCurrentTranche(scope: .defaultFeedback)
        }
    }
}

@Suite
struct RawLinuxDmabufFeedbackFormatTableFailureTests {
    @Test
    func formatTablePartialEntryReportsSize() {
        var state = RawLinuxDmabufFeedbackState()

        let error = RawLinuxDmabufFeedbackFormatTableFailure.classify(
            .invalidDmabufFormatTableByteCount(
                byteCount: 15,
                entryByteCount: RawLinuxDmabufFormatTable.entryByteCount
            ),
            state: &state,
            scope: .defaultFeedback,
            fileDescriptor: 8,
            byteCount: 15
        )

        #expect(
            error
                == malformedFeedback(
                    event: "format_table",
                    field: "size",
                    rawValue: 15,
                    discardedStaleState: false
                )
        )
    }

    @Test
    func formatTableInvalidFdReportsFd() {
        var state = RawLinuxDmabufFeedbackState()

        let error = RawLinuxDmabufFeedbackFormatTableFailure.classify(
            .system(
                RawSystemError(
                    uncheckedErrno: EINVAL,
                    operation: .validateArgument("dmabuf format table fd")
                )
            ),
            state: &state,
            scope: .defaultFeedback,
            fileDescriptor: -1,
            byteCount: 16
        )

        #expect(
            error
                == malformedFeedback(
                    event: "format_table",
                    field: "fd",
                    discardedStaleState: false
                )
        )
    }

    @Test
    func formatTableMapFailurePreservesSystemCause() {
        var state = RawLinuxDmabufFeedbackState()
        let mapFailure = RuntimeError.system(
            RawSystemError(
                uncheckedErrno: ENOMEM,
                operation: .mapDmabufFormatTable
            )
        )

        let error = RawLinuxDmabufFeedbackFormatTableFailure.classify(
            mapFailure,
            state: &state,
            scope: .defaultFeedback,
            fileDescriptor: 8,
            byteCount: 16
        )

        #expect(error == mapFailure)
    }
}

@Suite
struct RawLinuxDmabufVersionGateTests {
    @Test
    func defaultFeedbackRequiresVersionFour() {
        #expect(
            throws: RuntimeError.unsupportedProtocolVersion(
                interface: "zwp_linux_dmabuf_v1 feedback",
                minimum: 4,
                actual: 3
            )
        ) {
            try RawLinuxDmabuf.validateFeedbackRequestVersion(3)
        }

        #expect(throws: Never.self) {
            try RawLinuxDmabuf.validateFeedbackRequestVersion(4)
        }
    }

    @Test
    func surfaceFeedbackRequiresVersionFour() {
        #expect(
            throws: RuntimeError.unsupportedProtocolVersion(
                interface: "zwp_linux_dmabuf_v1 feedback",
                minimum: 4,
                actual: 2
            )
        ) {
            try RawLinuxDmabuf.validateFeedbackRequestVersion(2)
        }
    }

    @Test
    func createParamsAllowedOnVersionOne() {
        #expect(throws: Never.self) {
            try RawLinuxDmabuf.validateCreateParamsVersion(1)
        }
    }
}

private func malformedFeedback(
    event: String,
    field: String,
    index: Int? = nil,
    rawValue: UInt64? = nil,
    discardedStaleState: Bool = true
) -> RuntimeError {
    RuntimeError.malformedDmabufFeedback(
        RawLinuxDmabufMalformedFeedback(
            scope: .defaultFeedback,
            event: event,
            field: field,
            index: index,
            rawValue: rawValue,
            discardedStaleState: discardedStaleState
        )
    )
}
