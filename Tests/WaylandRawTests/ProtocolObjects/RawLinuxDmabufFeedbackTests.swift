import Glibc
import Testing

@testable import WaylandRaw

@Suite(.serialized)
struct RawLinuxDmabufFormatTableTests {
    @Test
    func parsesFormatModifierPairsFromReadOnlyMappedFd() throws {
        let entries = [
            RawLinuxDmabufFormatModifier(
                format: 0x3432_5258,
                modifier: 0x0102_0304_0506_0708
            ),
            RawLinuxDmabufFormatModifier(
                format: 0x3432_525A,
                modifier: 0x8877_6655_4433_2211
            ),
        ]
        let bytes = formatTableBytes(entries)
        var descriptor = try RawFileDescriptor.memfd(name: "swift-wayland-dmabuf-table")
        defer {
            descriptor.close()
        }
        try descriptor.resize(byteCount: bytes.count)
        #expect(
            try RawFileDescriptor.write(descriptor: descriptor.rawValue, bytes: bytes)
                == bytes.count
        )

        let parserDescriptor = Glibc.dup(descriptor.rawValue)
        #expect(parserDescriptor >= 0)

        let parsed = try RawLinuxDmabufFormatTable.parse(
            fileDescriptor: parserDescriptor,
            byteCount: UInt32(bytes.count)
        )

        #expect(parsed == entries)
    }

    @Test
    func rejectsPartialEntries() throws {
        let bytes = [UInt8](repeating: 0xAA, count: RawLinuxDmabufFormatTable.entryByteCount - 1)
        var descriptor = try RawFileDescriptor.memfd(name: "swift-wayland-dmabuf-table-bad")
        defer {
            descriptor.close()
        }
        try descriptor.resize(byteCount: bytes.count)
        #expect(
            try RawFileDescriptor.write(descriptor: descriptor.rawValue, bytes: bytes)
                == bytes.count
        )

        let parserDescriptor = Glibc.dup(descriptor.rawValue)
        #expect(parserDescriptor >= 0)

        do {
            _ = try RawLinuxDmabufFormatTable.parse(
                fileDescriptor: parserDescriptor,
                byteCount: UInt32(bytes.count)
            )
            Issue.record("Expected partial dmabuf format table to throw")
        } catch RuntimeError.invalidDmabufFormatTableByteCount(let byteCount, let entryByteCount) {
            #expect(byteCount == bytes.count)
            #expect(entryByteCount == RawLinuxDmabufFormatTable.entryByteCount)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

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
        state.setMainDevice(bytes: [0x01, 0x02, 0x03, 0x04])
        state.setCurrentTrancheTargetDevice(bytes: [0x05, 0x06, 0x07, 0x08])
        try state.appendCurrentTrancheFormats(indices: [1, 0])
        state.setCurrentTrancheFlags(RawLinuxDmabufTrancheFlags.scanout.rawValue | 0x8000_0000)
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
    }

    @Test
    func resentFeedbackReplacesPreviousSnapshot() throws {
        let firstEntry = RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        let replacementEntry = RawLinuxDmabufFormatModifier(format: 3, modifier: 4)
        var state = RawLinuxDmabufFeedbackState()

        state.replaceFormatTable([firstEntry])
        state.setMainDevice(bytes: [0x01])
        state.setCurrentTrancheTargetDevice(bytes: [0x02])
        state.setCurrentTrancheFlags(0)
        try state.appendCurrentTrancheFormats(indices: [0])
        try state.finishCurrentTranche(scope: .defaultFeedback)
        _ = try state.finish(scope: .defaultFeedback)

        state.replaceFormatTable([replacementEntry])
        state.setMainDevice(bytes: [0x03])
        state.setCurrentTrancheTargetDevice(bytes: [0x04])
        state.setCurrentTrancheFlags(0)
        try state.appendCurrentTrancheFormats(indices: [0])
        try state.finishCurrentTranche(scope: .defaultFeedback)

        let snapshot = try state.finish(scope: .defaultFeedback)

        #expect(snapshot.mainDevice == RawLinuxDmabufDevice(bytes: [0x03]))
        #expect(snapshot.formatTable == [replacementEntry])
        #expect(snapshot.tranches.count == 1)
        #expect(snapshot.tranches[0].targetDevice == RawLinuxDmabufDevice(bytes: [0x04]))
        #expect(snapshot.tranches[0].formats == [replacementEntry])
    }

    @Test
    func doneWithoutMainDeviceReportsFailureAndDoesNotPublishSnapshot() throws {
        var state = RawLinuxDmabufFeedbackState()
        state.replaceFormatTable([
            RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        ])
        state.setCurrentTrancheTargetDevice(bytes: [0x02])
        state.setCurrentTrancheFlags(0)
        try state.appendCurrentTrancheFormats(indices: [0])
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
        state.setCurrentTrancheFlags(0)
        try state.appendCurrentTrancheFormats(indices: [0])

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
    func trancheDoneWithoutFormatsReportsFailure() {
        var state = RawLinuxDmabufFeedbackState()
        state.replaceFormatTable([
            RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        ])
        state.setCurrentTrancheTargetDevice(bytes: [0x02])
        state.setCurrentTrancheFlags(0)

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
        state.setMainDevice(bytes: [0x01])
        state.setCurrentTrancheTargetDevice(bytes: [0x02])
        state.setCurrentTrancheFlags(0)
        try state.appendCurrentTrancheFormats(indices: [0])
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
        state.setMainDevice(bytes: [0x01])
        state.setCurrentTrancheTargetDevice(bytes: [0x02])
        state.setCurrentTrancheFlags(0)
        try state.appendCurrentTrancheFormats(indices: [0])

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
            try state.appendCurrentTrancheFormats(indices: [1])
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

private func formatTableBytes(_ entries: [RawLinuxDmabufFormatModifier]) -> [UInt8] {
    var bytes: [UInt8] = []
    for entry in entries {
        var format = entry.format
        unsafe withUnsafeBytes(of: &format) { formatBytes in
            bytes.append(contentsOf: unsafe Array(formatBytes))
        }
        bytes.append(contentsOf: [0, 0, 0, 0])
        var modifier = entry.modifier
        unsafe withUnsafeBytes(of: &modifier) { modifierBytes in
            bytes.append(contentsOf: unsafe Array(modifierBytes))
        }
    }

    return bytes
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
