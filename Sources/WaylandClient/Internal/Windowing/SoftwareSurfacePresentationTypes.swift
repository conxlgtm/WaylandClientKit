import WaylandRaw

struct SoftwareSurfacePresentationResult {
    let outcome: RedrawOutcome
    let followUp: SoftwareSurfacePresentationFollowUp?
}

struct ReservedSoftwareSurfaceFrame {
    let reservation: SoftwareFrameReservation
    let drawingBuffer: RawBuffer.ReservedDrawingBuffer
}

struct SoftwareSurfaceFrameReservationResult {
    let reservedFrame: ReservedSoftwareSurfaceFrame?
    let followUp: SoftwareSurfacePresentationFollowUp?
}

package enum SoftwareSurfaceFrameReservationOutcome: Equatable, Sendable {
    case reserved(SoftwareFrameReservation)
    case deferred
    case closed
}

enum SoftwareSurfacePresentationFollowUp {
    case fail(generation: UInt64, PresentationError)
    case blockedByBuffer
    case resetTransientState
    case succeeded(generation: UInt64)
}

struct SoftwareSurfacePresentationFailure: Error {
    let presentationError: PresentationError
    let underlying: any Error
}

package struct SoftwareSurfaceDrawFailure: Error {
    package let underlying: any Error

    package init(underlying drawError: any Error) {
        underlying = drawError
    }
}

package struct SurfacePresentationFeedbackCommitRequest {
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

package enum SoftwareSurfacePresentationCommitSequence {
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

struct SoftwareSurfacePresentationContext {
    let generation: UInt64
    let geometry: SurfaceGeometry
    let submitConstraints: SurfaceSubmitConstraints
    let metadata: SurfaceCommitMetadata
    let damage: SurfaceDamageRegion?
    let presentationFeedback: SurfacePresentationFeedbackCommitRequest?
}
