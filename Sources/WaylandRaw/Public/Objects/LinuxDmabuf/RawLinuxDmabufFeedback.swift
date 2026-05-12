import CWaylandProtocols
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

package struct RawLinuxDmabufFormatModifier: Equatable, Sendable {
    package let format: UInt32
    package let modifier: UInt64

    package init(format drmFormat: UInt32, modifier drmModifier: UInt64) {
        format = drmFormat
        modifier = drmModifier
    }
}

package struct RawLinuxDmabufTrancheFlags: OptionSet, Sendable {
    package let rawValue: UInt32

    package init(rawValue flags: UInt32) {
        rawValue = flags
    }

    package static let scanout = RawLinuxDmabufTrancheFlags(rawValue: 1)

    package var unknownRawValue: UInt32 {
        rawValue & ~Self.scanout.rawValue
    }
}

package struct RawLinuxDmabufTranche: Equatable, Sendable {
    package let targetDevice: RawLinuxDmabufDevice?
    package let flags: RawLinuxDmabufTrancheFlags
    package let formats: [RawLinuxDmabufFormatModifier]
}

package struct RawLinuxDmabufFeedbackSnapshot: Equatable, Sendable {
    package let scope: RawLinuxDmabufFeedbackScope
    package let mainDevice: RawLinuxDmabufDevice?
    package let formatTable: [RawLinuxDmabufFormatModifier]
    package let tranches: [RawLinuxDmabufTranche]
}

package enum RawLinuxDmabufFormatTable {
    package static let entryByteCount = 16

    package static func parse(
        fileDescriptor fd: Int32,
        byteCount rawByteCount: UInt32
    ) throws(RuntimeError) -> [RawLinuxDmabufFormatModifier] {
        guard fd >= 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .validateArgument("dmabuf format table fd")
            )
        }

        defer {
            Glibc.close(fd)
        }

        let byteCount = Int(rawByteCount)
        guard byteCount > 0 else { return [] }
        guard byteCount.isMultiple(of: entryByteCount) else {
            throw RuntimeError.invalidDmabufFormatTableByteCount(
                byteCount: byteCount,
                entryByteCount: entryByteCount
            )
        }

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
    private struct CurrentTranche: Equatable, Sendable {
        var targetDevice: RawLinuxDmabufDevice?
        var flags = RawLinuxDmabufTrancheFlags()
        var formats: [RawLinuxDmabufFormatModifier] = []
    }

    private var formatTable: [RawLinuxDmabufFormatModifier] = []
    private var mainDevice: RawLinuxDmabufDevice?
    private var currentTranche = CurrentTranche()
    private var tranches: [RawLinuxDmabufTranche] = []

    package init() {
        // Stored property defaults represent an empty feedback sequence.
    }

    package mutating func replaceFormatTable(
        _ formats: [RawLinuxDmabufFormatModifier]
    ) {
        formatTable = formats
    }

    package mutating func setMainDevice(bytes: [UInt8]) {
        mainDevice = RawLinuxDmabufDevice(bytes: bytes)
    }

    package mutating func setCurrentTrancheTargetDevice(bytes: [UInt8]) {
        currentTranche.targetDevice = RawLinuxDmabufDevice(bytes: bytes)
    }

    package mutating func appendCurrentTrancheFormats(indices: [UInt16])
        throws(RuntimeError)
    {
        var selectedFormats: [RawLinuxDmabufFormatModifier] = []
        for index in indices {
            let tableIndex = Int(index)
            guard tableIndex < formatTable.count else {
                throw RuntimeError.invalidDmabufFormatTableIndex(
                    index: index,
                    entryCount: formatTable.count
                )
            }

            selectedFormats.append(formatTable[tableIndex])
        }

        currentTranche.formats.append(contentsOf: selectedFormats)
    }

    package mutating func setCurrentTrancheFlags(_ rawFlags: UInt32) {
        currentTranche.flags = RawLinuxDmabufTrancheFlags(rawValue: rawFlags)
    }

    package mutating func finishCurrentTranche() {
        tranches.append(
            RawLinuxDmabufTranche(
                targetDevice: currentTranche.targetDevice,
                flags: currentTranche.flags,
                formats: currentTranche.formats
            )
        )
        currentTranche = CurrentTranche()
    }

    package func snapshot(scope feedbackScope: RawLinuxDmabufFeedbackScope)
        -> RawLinuxDmabufFeedbackSnapshot
    {
        RawLinuxDmabufFeedbackSnapshot(
            scope: feedbackScope,
            mainDevice: mainDevice,
            formatTable: formatTable,
            tranches: tranches
        )
    }
}

@safe
package final class RawLinuxDmabufFeedback {
    private let listenerOwner: RawLinuxDmabufFeedbackOwner
    private var proxy: RawOwnedProxy

    @safe
    init(
        pointer feedbackPointer: OpaquePointer,
        scope feedbackScope: RawLinuxDmabufFeedbackScope,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        onUpdate handleUpdate: @escaping (RawLinuxDmabufFeedbackSnapshot) -> Void,
        onFailure handleFailure: @escaping (RuntimeError) -> Void
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                feedbackPointer,
                interface: "zwp_linux_dmabuf_feedback_v1"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_zwp_linux_dmabuf_feedback_v1_destroy
            )
            listenerOwner = RawLinuxDmabufFeedbackOwner(
                scope: feedbackScope,
                invariantFailureSink: adoptionContext.invariantFailureSink,
                onUpdate: handleUpdate,
                onFailure: handleFailure
            )
            try unsafe listenerOwner.install(on: adoptedPointer)
        } catch {
            unsafe swl_zwp_linux_dmabuf_feedback_v1_destroy(feedbackPointer)
            throw error
        }
    }

    package func cancel() {
        listenerOwner.cancel()
        proxy.destroy()
    }

    deinit {
        cancel()
    }
}

@safe
private final class RawLinuxDmabufFeedbackOwner {
    private let scope: RawLinuxDmabufFeedbackScope
    private let invariantFailureSink: RawInvariantFailureSink?
    private let onUpdate: (RawLinuxDmabufFeedbackSnapshot) -> Void
    private let onFailure: (RuntimeError) -> Void
    private var state = RawLinuxDmabufFeedbackState()
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_linux_dmabuf_feedback_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_zwp_linux_dmabuf_feedback_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        scope feedbackScope: RawLinuxDmabufFeedbackScope,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        onUpdate handleUpdate: @escaping (RawLinuxDmabufFeedbackSnapshot) -> Void,
        onFailure handleFailure: @escaping (RuntimeError) -> Void
    ) {
        scope = feedbackScope
        invariantFailureSink = failureSink
        onUpdate = handleUpdate
        onFailure = handleFailure

        installDoneCallback()
        installFormatTableCallback()
        installMainDeviceCallback()
        installTrancheDoneCallback()
        installTrancheTargetDeviceCallback()
        installTrancheFormatsCallback()
        installTrancheFlagsCallback()
    }

    private func installDoneCallback() {
        unsafe callbacks.pointee.done = { data, _ in
            RawLinuxDmabufFeedbackOwner.withOwner(
                data,
                message: "zwp_linux_dmabuf_feedback_v1 done fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.onUpdate(owner.state.snapshot(scope: owner.scope))
            }
        }
    }

    private func installFormatTableCallback() {
        unsafe callbacks.pointee.format_table = { data, _, fd, size in
            guard unsafe data != nil else {
                Glibc.close(fd)
                return
            }
            RawLinuxDmabufFeedbackOwner.withOwner(
                data,
                message: "zwp_linux_dmabuf_feedback_v1 format_table fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else {
                    Glibc.close(fd)
                    return
                }
                owner.handleFormatTable(fileDescriptor: fd, byteCount: size)
            }
        }
    }

    private func installMainDeviceCallback() {
        unsafe callbacks.pointee.main_device = { data, _, device in
            RawLinuxDmabufFeedbackOwner.withOwner(
                data,
                message: "zwp_linux_dmabuf_feedback_v1 main_device fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.state.setMainDevice(bytes: WaylandArray.bytes(from: device))
            }
        }
    }

    private func installTrancheDoneCallback() {
        unsafe callbacks.pointee.tranche_done = { data, _ in
            RawLinuxDmabufFeedbackOwner.withOwner(
                data,
                message: "zwp_linux_dmabuf_feedback_v1 tranche_done fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.state.finishCurrentTranche()
            }
        }
    }

    private func installTrancheTargetDeviceCallback() {
        unsafe callbacks.pointee.tranche_target_device = { data, _, device in
            RawLinuxDmabufFeedbackOwner.withOwner(
                data,
                message: "zwp_linux_dmabuf_feedback_v1 target_device fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.state.setCurrentTrancheTargetDevice(
                    bytes: WaylandArray.bytes(from: device)
                )
            }
        }
    }

    private func installTrancheFormatsCallback() {
        unsafe callbacks.pointee.tranche_formats = { data, _, indices in
            RawLinuxDmabufFeedbackOwner.withOwner(
                data,
                message: "zwp_linux_dmabuf_feedback_v1 tranche_formats fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                unsafe owner.handleTrancheFormats(indices: indices)
            }
        }
    }

    private func installTrancheFlagsCallback() {
        unsafe callbacks.pointee.tranche_flags = { data, _, flags in
            RawLinuxDmabufFeedbackOwner.withOwner(
                data,
                message: "zwp_linux_dmabuf_feedback_v1 tranche_flags fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.state.setCurrentTrancheFlags(flags)
            }
        }
    }

    func install(on feedback: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_zwp_linux_dmabuf_feedback_v1_add_listener(
            feedback,
            callbacks
        )
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("zwp_linux_dmabuf_feedback_v1")
            )
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func handleFormatTable(fileDescriptor fd: Int32, byteCount: UInt32) {
        do {
            let formats = try RawLinuxDmabufFormatTable.parse(
                fileDescriptor: fd,
                byteCount: byteCount
            )
            state.replaceFormatTable(formats)
        } catch {
            onFailure(error)
        }
    }

    private func handleTrancheFormats(indices: UnsafeMutablePointer<wl_array>?) {
        do {
            let decodedIndices = try WaylandArray.uint16Values(from: indices)
            try state.appendCurrentTrancheFormats(indices: decodedIndices)
        } catch {
            onFailure(error)
        }
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawLinuxDmabufFeedbackOwner) -> Void
    ) {
        CListenerStorage<
            RawLinuxDmabufFeedbackOwner,
            swl_zwp_linux_dmabuf_feedback_listener_callbacks
        >.withOwner(from: data, message: message(), body)
    }
}
