import CWaylandProtocols
import Glibc

package struct RawPresentationTimestamp: Equatable, Sendable {
    package let seconds: UInt64
    package let nanoseconds: UInt32

    package init(tvSecHi: UInt32, tvSecLo: UInt32, tvNsec: UInt32) {
        seconds = (UInt64(tvSecHi) << 32) | UInt64(tvSecLo)
        nanoseconds = tvNsec
    }
}

package struct RawPresentationSequence: Equatable, Sendable {
    package let value: UInt64

    package init(seqHi: UInt32, seqLo: UInt32) {
        value = (UInt64(seqHi) << 32) | UInt64(seqLo)
    }
}

package struct RawPresentationPresented: Equatable, Sendable {
    package let timestamp: RawPresentationTimestamp
    package let refreshNanoseconds: UInt32
    package let sequence: RawPresentationSequence
    package let flags: UInt32
    package let synchronizedOutput: RawOutputPointerIdentity?

    package init(
        timestamp presentationTimestamp: RawPresentationTimestamp,
        refreshNanoseconds presentationRefreshNanoseconds: UInt32,
        sequence presentationSequence: RawPresentationSequence,
        flags presentationFlags: UInt32,
        synchronizedOutput presentationSynchronizedOutput: RawOutputPointerIdentity?
    ) {
        timestamp = presentationTimestamp
        refreshNanoseconds = presentationRefreshNanoseconds
        sequence = presentationSequence
        flags = presentationFlags
        synchronizedOutput = presentationSynchronizedOutput
    }
}

package enum RawPresentationFeedbackEvent: Equatable, Sendable {
    case presented(RawPresentationPresented)
    case discarded
}

@safe
package final class RawPresentation {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private let listenerOwner: RawPresentationOwner
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    package private(set) var clockID: UInt32?

    @safe
    init(
        pointer presentationPointer: OpaquePointer,
        version presentationVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                presentationPointer,
                interface: "wp_presentation"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_wp_presentation_destroy
            )
            version = presentationVersion
            proxyAdoption = adoptionContext
            listenerOwner = RawPresentationOwner(
                invariantFailureSink: adoptionContext.invariantFailureSink
            )
            try unsafe listenerOwner.install(on: adoptedPointer) { [weak self] clockID in
                self?.clockID = clockID
            }
        } catch {
            unsafe swl_wp_presentation_destroy(presentationPointer)
            throw error
        }
    }

    package func requestFeedback(
        for surface: RawSurface,
        onEvent handler: @escaping (RawPresentationFeedbackEvent) -> Void
    ) throws -> RawPresentationFeedback {
        guard
            let feedback = unsafe swl_wp_presentation_feedback(pointer, surface.pointer)
        else {
            throw RuntimeError.bindFailed("wp_presentation_feedback")
        }

        do {
            _ = try proxyAdoption.adopt(feedback, interface: "wp_presentation_feedback")
        } catch {
            unsafe swl_wp_presentation_feedback_destroy(feedback)
            throw error
        }

        return try RawPresentationFeedback(
            pointer: feedback,
            invariantFailureSink: proxyAdoption.invariantFailureSink,
            onEvent: handler
        )
    }

    package func destroy() {
        listenerOwner.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
private final class RawPresentationOwner {
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isCanceled = false
    private var onClockID: ((UInt32) -> Void)?
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_wp_presentation_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_wp_presentation_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(invariantFailureSink failureSink: RawInvariantFailureSink? = nil) {
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.clock_id = { data, _, clockID in
            RawPresentationOwner.withOwner(
                data,
                message: "wp_presentation clock_id fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.onClockID?(clockID)
            }
        }
    }

    func install(on presentation: OpaquePointer, onClockID handler: @escaping (UInt32) -> Void)
        throws(RuntimeError)
    {
        guard onClockID == nil else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("wp_presentation")
            )
        }

        onClockID = handler
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_wp_presentation_add_listener(presentation, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("wp_presentation")
            )
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawPresentationOwner) -> Void
    ) {
        CListenerStorage<
            RawPresentationOwner,
            swl_wp_presentation_listener_callbacks
        >.withOwner(from: data, message: message(), body)
    }
}

@safe
package final class RawPresentationFeedback {
    private let listenerOwner: RawPresentationFeedbackOwner
    @safe private let pointer: OpaquePointer
    private var isTerminal = false

    @safe
    init(
        pointer feedbackPointer: OpaquePointer,
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent handler: @escaping (RawPresentationFeedbackEvent) -> Void
    ) throws(RuntimeError) {
        unsafe pointer = feedbackPointer
        listenerOwner = RawPresentationFeedbackOwner(
            invariantFailureSink: failureSink,
            onEvent: handler
        )
        try unsafe listenerOwner.install(on: feedbackPointer) { [weak self] in
            self?.markTerminal()
        }
    }

    package func cancel() {
        guard !isTerminal else { return }

        isTerminal = true
        listenerOwner.cancel()
        unsafe swl_wp_presentation_feedback_destroy(pointer)
    }

    private func markTerminal() {
        isTerminal = true
        listenerOwner.cancel()
    }

    deinit {
        cancel()
    }
}

@safe
private final class RawPresentationFeedbackOwner {
    private let invariantFailureSink: RawInvariantFailureSink?
    private let onEvent: (RawPresentationFeedbackEvent) -> Void
    private var onTerminal: (() -> Void)?
    private var synchronizedOutput: RawOutputPointerIdentity?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_wp_presentation_feedback_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_wp_presentation_feedback_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        onEvent handler: @escaping (RawPresentationFeedbackEvent) -> Void
    ) {
        invariantFailureSink = failureSink
        onEvent = handler

        unsafe callbacks.pointee.sync_output = { data, _, output in
            RawPresentationFeedbackOwner.withOwner(
                data,
                message: "wp_presentation_feedback sync_output fired without Swift state"
            ) { owner in
                guard !owner.isCanceled, let output = unsafe output else { return }
                owner.synchronizedOutput = RawOutputPointerIdentity(output)
            }
        }

        // swiftlint:disable closure_parameter_position
        unsafe callbacks.pointee.presented = {
            data,
            _,
            tvSecHi,
            tvSecLo,
            tvNsec,
            refresh,
            seqHi,
            seqLo,
            flags in
            RawPresentationFeedbackOwner.withOwner(
                data,
                message: "wp_presentation_feedback presented fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                let presented = RawPresentationPresented(
                    timestamp: RawPresentationTimestamp(
                        tvSecHi: tvSecHi,
                        tvSecLo: tvSecLo,
                        tvNsec: tvNsec
                    ),
                    refreshNanoseconds: refresh,
                    sequence: RawPresentationSequence(seqHi: seqHi, seqLo: seqLo),
                    flags: flags,
                    synchronizedOutput: owner.synchronizedOutput
                )
                owner.finish(.presented(presented))
            }
        }
        // swiftlint:enable closure_parameter_position

        unsafe callbacks.pointee.discarded = { data, _ in
            RawPresentationFeedbackOwner.withOwner(
                data,
                message: "wp_presentation_feedback discarded fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.finish(.discarded)
            }
        }
    }

    func install(on feedback: OpaquePointer, onTerminal handleTerminal: @escaping () -> Void)
        throws(RuntimeError)
    {
        guard onTerminal == nil else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("wp_presentation_feedback")
            )
        }

        onTerminal = handleTerminal
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_wp_presentation_feedback_add_listener(feedback, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("wp_presentation_feedback")
            )
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func finish(_ event: RawPresentationFeedbackEvent) {
        let terminal = onTerminal
        isCanceled = true
        listenerStorage.invalidate()
        onEvent(event)
        terminal?()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawPresentationFeedbackOwner) -> Void
    ) {
        CListenerStorage<
            RawPresentationFeedbackOwner,
            swl_wp_presentation_feedback_listener_callbacks
        >.withOwner(from: data, message: message(), body)
    }
}
