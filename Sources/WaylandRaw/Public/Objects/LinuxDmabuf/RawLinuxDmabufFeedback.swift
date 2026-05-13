import CWaylandProtocols
import Glibc

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
                do {
                    let snapshot = try owner.state.finish(scope: owner.scope)
                    owner.onUpdate(snapshot)
                } catch {
                    owner.onFailure(RawLinuxDmabufFeedbackOwner.runtimeError(from: error))
                }
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
                do {
                    try owner.state.setMainDevice(
                        bytes: WaylandArray.bytes(from: device),
                        scope: owner.scope
                    )
                } catch {
                    owner.onFailure(RawLinuxDmabufFeedbackOwner.runtimeError(from: error))
                }
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
                do {
                    try owner.state.finishCurrentTranche(scope: owner.scope)
                } catch {
                    owner.onFailure(RawLinuxDmabufFeedbackOwner.runtimeError(from: error))
                }
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
                do {
                    try owner.state.setCurrentTrancheTargetDevice(
                        bytes: WaylandArray.bytes(from: device),
                        scope: owner.scope
                    )
                } catch {
                    owner.onFailure(RawLinuxDmabufFeedbackOwner.runtimeError(from: error))
                }
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
                do {
                    try owner.state.setCurrentTrancheFlags(flags, scope: owner.scope)
                } catch {
                    owner.onFailure(RawLinuxDmabufFeedbackOwner.runtimeError(from: error))
                }
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
            onFailure(
                RawLinuxDmabufFeedbackFormatTableFailure.classify(
                    error,
                    state: &state,
                    scope: scope,
                    fileDescriptor: fd,
                    byteCount: byteCount
                )
            )
        }
    }

    private func handleTrancheFormats(indices: UnsafeMutablePointer<wl_array>?) {
        do {
            let decodedIndices = try WaylandArray.uint16Values(from: indices)
            try state.appendCurrentTrancheFormats(indices: decodedIndices, scope: scope)
        } catch RuntimeError.invalidDmabufFormatTableIndex(let index, _) {
            onFailure(
                state.invalidateFeedback(
                    scope: scope,
                    event: "tranche_formats",
                    field: "indices",
                    index: Int(index),
                    rawValue: UInt64(index)
                )
            )
        } catch {
            onFailure(
                state.invalidateFeedback(
                    scope: scope,
                    event: "tranche_formats",
                    field: "indices"
                )
            )
        }
    }

    private static func runtimeError(from error: any Error) -> RuntimeError {
        if let runtimeError = error as? RuntimeError {
            return runtimeError
        }

        return RuntimeError.systemError(
            errno: EINVAL,
            operation: .validateArgument(String(describing: error))
        )
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

package enum RawLinuxDmabufFeedbackFormatTableFailure {
    package static func classify(
        _ error: RuntimeError,
        state: inout RawLinuxDmabufFeedbackState,
        scope feedbackScope: RawLinuxDmabufFeedbackScope,
        fileDescriptor fd: Int32,
        byteCount: UInt32
    ) -> RuntimeError {
        switch error {
        case .invalidDmabufFormatTableByteCount:
            return state.invalidateFeedback(
                scope: feedbackScope,
                event: "format_table",
                field: "size",
                rawValue: UInt64(byteCount)
            )
        case .system(let systemError)
        where systemError.operation == .validateArgument("dmabuf format table fd"):
            return state.invalidateFeedback(
                scope: feedbackScope,
                event: "format_table",
                field: "fd",
                rawValue: fd >= 0 ? UInt64(fd) : nil
            )
        default:
            return error
        }
    }
}
