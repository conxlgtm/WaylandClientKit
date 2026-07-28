extension WaylandDisplay {
    package func reservePopupSoftwareFrameForShow(
        id: PopupID,
        timeoutMilliseconds: Int32,
        metadata: SurfaceFrameMetadata
    ) throws -> SoftwareSurfaceFrameReservationOutcome {
        guard let core = coreIfActive() else { return .closed }
        return try core.reservePopupSoftwareFrameForShow(
            id: id,
            timeoutMilliseconds: timeoutMilliseconds,
            metadata: metadata
        )
    }

    package func reservePopupSoftwareFrameForRedraw(
        id: PopupID,
        metadata: SurfaceFrameMetadata
    ) throws -> SoftwareSurfaceFrameReservationOutcome {
        guard let core = coreIfActive() else { return .closed }
        return try core.reservePopupSoftwareFrameForRedraw(id: id, metadata: metadata)
    }

    package func submitReservedPopupSoftwareFrame(
        id: PopupID,
        reservation: SoftwareFrameReservation,
        metadata: SurfaceFrameMetadata,
        requestPresentationFeedback: Bool,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws -> SoftwarePresentationOutcome {
        guard let core = coreIfActive() else { return .closed }
        return try core.submitReservedPopupSoftwareFrame(
            id: id,
            reservation: reservation,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            draw
        )
    }

    package func cancelReservedPopupSoftwareFrame(
        id: PopupID,
        reservation: SoftwareFrameReservation
    ) throws {
        guard let core = coreIfActive() else { return }
        core.cancelReservedPopupSoftwareFrame(id: id, reservation: reservation)
    }
}
