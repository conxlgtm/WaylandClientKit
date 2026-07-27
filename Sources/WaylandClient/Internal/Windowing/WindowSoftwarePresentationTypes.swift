import WaylandRaw

struct WindowSoftwarePresentationResult {
    let outcome: RedrawOutcome
    let followUp: WindowSoftwarePresentationFollowUp?
}

struct WindowReservedSoftwareFrame {
    let reservation: SoftwareFrameReservation
    let drawingBuffer: RawBuffer.ReservedDrawingBuffer
}

struct WindowSoftwareFrameReservationResult {
    let reservedFrame: WindowReservedSoftwareFrame?
    let followUp: WindowSoftwarePresentationFollowUp?
}

package enum WindowSoftwareFrameReservationOutcome: Equatable, Sendable {
    case reserved(SoftwareFrameReservation)
    case deferred
    case closed
}

enum WindowSoftwarePresentationFollowUp {
    case fail(generation: UInt64, PresentationError)
    case blockedByBuffer
    case resetTransientState
    case succeeded(generation: UInt64)
}

struct WindowSoftwarePresentationFailure: Error {
    let presentationError: PresentationError
    let underlying: any Error
}

package struct WindowSoftwareDrawFailure: Error {
    package let underlying: any Error

    package init(underlying drawError: any Error) {
        underlying = drawError
    }
}

package struct WindowPresentationFeedbackCommitRequest {
    let request: () throws -> SurfacePresentationIdentity
    let cancel: (SurfacePresentationIdentity) -> Void

    package init(
        request feedbackRequest: @escaping () throws -> SurfacePresentationIdentity,
        cancel cancelFeedback: @escaping (SurfacePresentationIdentity) -> Void
    ) {
        request = feedbackRequest
        cancel = cancelFeedback
    }
}

package enum WindowSoftwarePresentationCommitSequence {
    @discardableResult
    package static func perform(
        stageSuccess: () throws -> Void,
        markDrawingBufferBusy: () -> Void,
        requestFrameCallback: () -> Void,
        requestPresentationFeedback: () -> SurfacePresentationIdentity?,
        commit: () -> Void
    ) rethrows -> SurfacePresentationIdentity? {
        try stageSuccess()
        markDrawingBufferBusy()
        requestFrameCallback()
        let feedbackIdentity = requestPresentationFeedback()
        commit()
        return feedbackIdentity
    }
}

struct WindowSoftwarePresentationContext {
    let request: PresentationRequest
    let geometry: SurfaceGeometry
    let submitConstraints: SurfaceSubmitConstraints
    let metadata: SurfaceCommitMetadata
    let damage: SurfaceDamageRegion?
    let presentationFeedback: WindowPresentationFeedbackCommitRequest?
}
