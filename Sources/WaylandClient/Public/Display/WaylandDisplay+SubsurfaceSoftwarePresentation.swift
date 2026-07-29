extension WaylandDisplay {
    package func reserveSubsurfaceSoftwareFrameForShow(
        id: SubsurfaceID,
        metadata: SurfaceFrameMetadata
    ) throws -> SoftwareSurfaceFrameReservationOutcome {
        guard let core = coreIfActive() else { return .closed }
        return try core.reserveSubsurfaceSoftwareFrameForShow(id: id, metadata: metadata)
    }

    package func reserveSubsurfaceSoftwareFrameForRedraw(
        id: SubsurfaceID,
        metadata: SurfaceFrameMetadata
    ) throws -> SoftwareSurfaceFrameReservationOutcome {
        guard let core = coreIfActive() else { return .closed }
        return try core.reserveSubsurfaceSoftwareFrameForRedraw(id: id, metadata: metadata)
    }

    // swiftlint:disable:next function_parameter_count
    package func submitReservedSubsurfaceSoftwareFrame<Prepared: Sendable>(
        id: SubsurfaceID,
        reservation: SoftwareFrameReservation,
        metadata: SurfaceFrameMetadata,
        requestPresentationFeedback: Bool,
        prepared: sending Prepared,
        _ draw: sending @Sendable (Prepared, borrowing SoftwareFrame) throws -> Void
    ) throws -> SoftwarePresentationOutcome {
        guard let core = coreIfActive() else { return .closed }
        return try core.submitReservedSubsurfaceSoftwareFrame(
            id: id,
            reservation: reservation,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            prepared: prepared,
            draw
        )
    }

    package func cancelReservedSubsurfaceSoftwareFrame(
        id: SubsurfaceID,
        reservation: SoftwareFrameReservation
    ) throws {
        guard let core = coreIfActive() else { return }
        try core.cancelReservedSubsurfaceSoftwareFrame(
            id: id,
            reservation: reservation
        )
    }
}
