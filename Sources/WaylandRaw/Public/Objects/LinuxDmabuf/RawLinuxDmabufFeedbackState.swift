import Glibc

package enum RawLinuxDmabufFeedbackScope: Equatable, Sendable {
    case defaultFeedback
    case surface(surfaceID: RawObjectID)
}

package struct RawLinuxDmabufDevice: Equatable, Sendable {
    package let bytes: [UInt8]

    package init(bytes deviceBytes: [UInt8]) {
        bytes = deviceBytes
    }
}

package struct RawLinuxDmabufFormatModifier: Equatable, Hashable, Sendable {
    package let format: UInt32
    package let modifier: UInt64

    package init(format drmFormat: UInt32, modifier drmModifier: UInt64) {
        format = drmFormat
        modifier = drmModifier
    }
}

package struct RawLinuxDmabufTrancheFlags: OptionSet, Sendable, KnownUInt32OptionSet {
    package let rawValue: UInt32

    package init(rawValue flags: UInt32) {
        rawValue = flags
    }

    package static let scanout = RawLinuxDmabufTrancheFlags(rawValue: 1)
    package static let known: RawLinuxDmabufTrancheFlags = [.scanout]
}

package struct RawLinuxDmabufTranche: Equatable, Sendable {
    package let targetDevice: RawLinuxDmabufDevice
    package let flags: RawLinuxDmabufTrancheFlags
    package let formats: [RawLinuxDmabufFormatModifier]

    package init(
        targetDevice trancheTargetDevice: RawLinuxDmabufDevice,
        flags trancheFlags: RawLinuxDmabufTrancheFlags,
        formats trancheFormats: [RawLinuxDmabufFormatModifier],
        validatedBy _: RawLinuxDmabufFeedbackState.ValidatedConstructionToken
    ) {
        targetDevice = trancheTargetDevice
        flags = trancheFlags
        formats = trancheFormats
    }

    package func formatModifiers(for format: UInt32) -> [RawLinuxDmabufFormatModifier] {
        formats.filter { $0.format == format }
    }
}

extension Sequence where Element == RawLinuxDmabufFormatModifier {
    package var modifiers: [UInt64] {
        map(\.modifier)
    }
}

package struct RawLinuxDmabufFeedbackSnapshot: Equatable, Sendable {
    package let scope: RawLinuxDmabufFeedbackScope
    package let mainDevice: RawLinuxDmabufDevice
    package let formatTable: [RawLinuxDmabufFormatModifier]
    package let tranches: [RawLinuxDmabufTranche]

    package init(
        scope feedbackScope: RawLinuxDmabufFeedbackScope,
        mainDevice feedbackMainDevice: RawLinuxDmabufDevice,
        formatTable feedbackFormatTable: [RawLinuxDmabufFormatModifier],
        tranches feedbackTranches: [RawLinuxDmabufTranche],
        validatedBy _: RawLinuxDmabufFeedbackState.ValidatedConstructionToken
    ) {
        scope = feedbackScope
        mainDevice = feedbackMainDevice
        formatTable = feedbackFormatTable
        tranches = feedbackTranches
    }
}

package enum RawLinuxDmabufFormatTable {
    package static let entryByteCount = 16

    package static func parse(
        fileDescriptor fd: Int32,
        byteCount rawByteCount: UInt32
    ) throws(RuntimeError) -> [RawLinuxDmabufFormatModifier] {
        guard fd >= 0 else {
            throw RuntimeError.invalidArgument("dmabuf format table fd")
        }

        defer {
            Glibc.close(fd)
        }

        let byteCount = Int(rawByteCount)
        guard byteCount.isMultiple(of: entryByteCount) else {
            throw RuntimeError.invalidDmabufFormatTableByteCount(
                byteCount: byteCount,
                entryByteCount: entryByteCount
            )
        }
        var fileStatus = stat()
        guard unsafe Glibc.fstat(fd, &fileStatus) == 0 else {
            throw RuntimeError.systemError(errno: errno, operation: .mapDmabufFormatTable)
        }
        guard fileStatus.st_size >= 0, UInt64(fileStatus.st_size) >= UInt64(rawByteCount) else {
            throw RuntimeError.invalidDmabufFormatTableByteCount(
                byteCount: byteCount,
                entryByteCount: entryByteCount
            )
        }
        guard byteCount > 0 else { return [] }

        let failedMapping = unsafe MAP_FAILED
        guard
            let mapping = unsafe mmap(nil, byteCount, PROT_READ, MAP_PRIVATE, fd, 0),
            unsafe mapping != failedMapping
        else {
            throw RuntimeError.systemError(errno: errno, operation: .mapDmabufFormatTable)
        }

        defer {
            unsafe munmap(mapping, byteCount)
        }

        let bytes = unsafe UnsafeRawBufferPointer(start: mapping, count: byteCount)
        return stride(from: 0, to: byteCount, by: entryByteCount).map { offset in
            RawLinuxDmabufFormatModifier(
                format: unsafe bytes.loadUnaligned(
                    fromByteOffset: offset,
                    as: UInt32.self
                ),
                modifier: unsafe bytes.loadUnaligned(
                    fromByteOffset: offset + 8,
                    as: UInt64.self
                )
            )
        }
    }
}

package struct RawLinuxDmabufFeedbackState: Equatable, Sendable {
    package struct ValidatedConstructionToken: Equatable, Sendable {
        // Compiler-synthesized initializer stays internal to WaylandRaw.
    }

    private static let validatedConstructionToken = ValidatedConstructionToken()

    private struct CurrentTranche: Equatable, Sendable {
        var targetDevice: RawLinuxDmabufDevice?
        var flags: RawLinuxDmabufTrancheFlags?
        var formats: [RawLinuxDmabufFormatModifier] = []

        var isEmpty: Bool {
            targetDevice == nil && flags == nil && formats.isEmpty
        }
    }

    private struct FeedbackBatch: Equatable, Sendable {
        var formatTable: [RawLinuxDmabufFormatModifier] = []
        var mainDevice: RawLinuxDmabufDevice?
        var currentTranche = CurrentTranche()
        var tranches: [RawLinuxDmabufTranche] = []

        var isEmpty: Bool {
            formatTable.isEmpty
                && mainDevice == nil
                && currentTranche.isEmpty
                && tranches.isEmpty
        }
    }

    private var batch = FeedbackBatch()
    private var malformedFeedback: RuntimeError?
    private var startsFreshBatchOnNextEvent = false

    package init() {
        // Stored property defaults represent an empty feedback sequence.
    }

    package mutating func replaceFormatTable(
        _ formats: [RawLinuxDmabufFormatModifier]
    ) {
        prepareForEvent()
        guard malformedFeedback == nil else { return }

        batch.formatTable = formats
    }

    package mutating func setMainDevice(
        bytes: [UInt8],
        scope feedbackScope: RawLinuxDmabufFeedbackScope
    ) throws(RuntimeError) {
        try prepareForValidEvent()
        guard batch.mainDevice == nil else {
            throw invalidateFeedback(
                scope: feedbackScope,
                event: "main_device",
                field: "main_device"
            )
        }

        batch.mainDevice = RawLinuxDmabufDevice(bytes: bytes)
    }

    package mutating func setCurrentTrancheTargetDevice(
        bytes: [UInt8],
        scope feedbackScope: RawLinuxDmabufFeedbackScope
    ) throws(RuntimeError) {
        try prepareForValidEvent()
        guard batch.currentTranche.targetDevice == nil else {
            throw invalidateFeedback(
                scope: feedbackScope,
                event: "tranche_target_device",
                field: "tranche_target_device"
            )
        }

        batch.currentTranche.targetDevice = RawLinuxDmabufDevice(bytes: bytes)
    }

    package mutating func appendCurrentTrancheFormats(
        indices: [UInt16],
        scope feedbackScope: RawLinuxDmabufFeedbackScope
    )
        throws(RuntimeError)
    {
        try prepareForValidEvent()

        var trancheFormats = batch.currentTranche.formats
        for (offset, index) in indices.enumerated() {
            let tableIndex = Int(index)
            guard tableIndex < batch.formatTable.count else {
                throw RuntimeError.invalidDmabufFormatTableIndex(
                    index: index,
                    entryCount: batch.formatTable.count
                )
            }

            let format = batch.formatTable[tableIndex]
            guard !trancheFormats.contains(format) else {
                throw invalidateFeedback(
                    scope: feedbackScope,
                    event: "tranche_formats",
                    field: "formats",
                    index: batch.currentTranche.formats.count + offset,
                    rawValue: UInt64(index)
                )
            }
            trancheFormats.append(format)
        }

        batch.currentTranche.formats = trancheFormats
    }

    package mutating func setCurrentTrancheFlags(
        _ rawFlags: UInt32,
        scope feedbackScope: RawLinuxDmabufFeedbackScope
    ) throws(RuntimeError) {
        try prepareForValidEvent()
        guard batch.currentTranche.flags == nil else {
            throw invalidateFeedback(
                scope: feedbackScope,
                event: "tranche_flags",
                field: "tranche_flags"
            )
        }

        batch.currentTranche.flags = RawLinuxDmabufTrancheFlags(rawValue: rawFlags)
    }

    package mutating func finishCurrentTranche(
        scope feedbackScope: RawLinuxDmabufFeedbackScope
    ) throws(RuntimeError) {
        try prepareForValidEvent()

        guard let targetDevice = batch.currentTranche.targetDevice else {
            throw invalidateFeedback(
                scope: feedbackScope,
                event: "tranche_done",
                field: "tranche_target_device"
            )
        }
        guard let flags = batch.currentTranche.flags else {
            throw invalidateFeedback(
                scope: feedbackScope,
                event: "tranche_done",
                field: "tranche_flags"
            )
        }
        guard !batch.currentTranche.formats.isEmpty else {
            throw invalidateFeedback(
                scope: feedbackScope,
                event: "tranche_done",
                field: "tranche_formats"
            )
        }
        if let duplicate = duplicateFormatInExistingTranche(
            targetDevice: targetDevice,
            flags: flags,
            formats: batch.currentTranche.formats
        ) {
            throw invalidateFeedback(
                scope: feedbackScope,
                event: "tranche_done",
                field: "tranche_formats",
                index: duplicate.index,
                rawValue: duplicate.rawValue
            )
        }

        batch.tranches.append(
            RawLinuxDmabufTranche(
                targetDevice: targetDevice,
                flags: flags,
                formats: batch.currentTranche.formats,
                validatedBy: Self.validatedConstructionToken
            )
        )
        batch.currentTranche = CurrentTranche()
    }

    package mutating func finish(scope feedbackScope: RawLinuxDmabufFeedbackScope)
        throws(RuntimeError) -> RawLinuxDmabufFeedbackSnapshot
    {
        do {
            try prepareForValidEvent()
        } catch {
            startsFreshBatchOnNextEvent = true
            throw error
        }

        guard let mainDevice = batch.mainDevice else {
            try finishFailure(scope: feedbackScope, field: "main_device")
        }
        guard batch.currentTranche.isEmpty else {
            try finishFailure(scope: feedbackScope, field: "tranche_done")
        }
        guard !batch.tranches.isEmpty else {
            try finishFailure(scope: feedbackScope, field: "tranche")
        }

        startsFreshBatchOnNextEvent = true
        return RawLinuxDmabufFeedbackSnapshot(
            scope: feedbackScope,
            mainDevice: mainDevice,
            formatTable: batch.formatTable,
            tranches: batch.tranches,
            validatedBy: Self.validatedConstructionToken
        )
    }

    @discardableResult
    package mutating func invalidateFeedback(
        scope feedbackScope: RawLinuxDmabufFeedbackScope,
        event: String,
        field: String,
        index: Int? = nil,
        rawValue: UInt64? = nil
    ) -> RuntimeError {
        if let malformedFeedback {
            return malformedFeedback
        }

        let discardedStaleState = startsFreshBatchOnNextEvent || !batch.isEmpty
        startsFreshBatchOnNextEvent = false
        batch = FeedbackBatch()
        let error = RuntimeError.malformedDmabufFeedback(
            RawLinuxDmabufMalformedFeedback(
                scope: feedbackScope,
                event: event,
                field: field,
                index: index,
                rawValue: rawValue,
                discardedStaleState: discardedStaleState
            )
        )
        malformedFeedback = error
        return error
    }

    private mutating func prepareForEvent() {
        guard startsFreshBatchOnNextEvent else { return }

        batch = FeedbackBatch()
        malformedFeedback = nil
        startsFreshBatchOnNextEvent = false
    }

    private mutating func prepareForValidEvent() throws(RuntimeError) {
        prepareForEvent()

        if let malformedFeedback {
            throw malformedFeedback
        }
    }

    private mutating func finishFailure(
        scope feedbackScope: RawLinuxDmabufFeedbackScope,
        field: String
    ) throws(RuntimeError) -> Never {
        let error = invalidateFeedback(
            scope: feedbackScope,
            event: "done",
            field: field
        )
        startsFreshBatchOnNextEvent = true
        throw error
    }
}

extension RawLinuxDmabufFeedbackState {
    private func duplicateFormatInExistingTranche(
        targetDevice: RawLinuxDmabufDevice,
        flags: RawLinuxDmabufTrancheFlags,
        formats: [RawLinuxDmabufFormatModifier]
    ) -> (index: Int, rawValue: UInt64)? {
        for tranche in batch.tranches
        where tranche.targetDevice == targetDevice && tranche.flags == flags {
            for (index, format) in formats.enumerated()
            where tranche.formatModifiers(for: format.format).contains(format) {
                return (index, UInt64(format.format))
            }
        }

        return nil
    }
}
