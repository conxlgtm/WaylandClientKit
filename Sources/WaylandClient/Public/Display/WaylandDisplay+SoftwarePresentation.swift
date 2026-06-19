extension WaylandDisplay {
    package func showWindow(
        _ windowID: WindowID,
        timeoutMilliseconds: Int32 = defaultConfigureTimeoutMilliseconds,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try showWindow(
            windowID,
            timeoutMilliseconds: timeoutMilliseconds,
            submitConstraints: .default,
            metadata: .default,
            requestPresentationFeedback: false,
            damage: nil,
            draw
        )
    }

    // swiftlint:disable:next function_parameter_count
    package func showWindow(
        _ windowID: WindowID,
        timeoutMilliseconds: Int32,
        submitConstraints: SurfaceSubmitConstraints,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion? = nil,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().showWindow(
            windowID,
            timeoutMilliseconds: timeoutMilliseconds,
            submitConstraints: submitConstraints,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            damage: damage,
            draw
        )
    }

    package func reserveSoftwareFrameForShow(
        _ windowID: WindowID,
        timeoutMilliseconds: Int32
    ) throws -> SoftwareFrameReservation? {
        try requireCore().reserveSoftwareFrameForShow(
            windowID,
            timeoutMilliseconds: timeoutMilliseconds
        )
    }

    package func redraw(
        _ windowID: WindowID,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try redraw(
            windowID,
            submitConstraints: .default,
            metadata: .default,
            requestPresentationFeedback: false,
            damage: nil,
            draw
        )
    }

    package func redraw(
        _ windowID: WindowID,
        submitConstraints: SurfaceSubmitConstraints,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion? = nil,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().redraw(
            windowID,
            submitConstraints: submitConstraints,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            damage: damage,
            draw
        )
    }

    package func reserveSoftwareFrameForRedraw(
        _ windowID: WindowID
    ) throws -> SoftwareFrameReservation? {
        try requireCore().reserveSoftwareFrameForRedraw(windowID)
    }

    // swiftlint:disable:next function_parameter_count
    package func submitReservedSoftwareFrame(
        _ windowID: WindowID,
        reservation: SoftwareFrameReservation,
        submitConstraints: SurfaceSubmitConstraints,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion? = nil,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().submitReservedSoftwareFrame(
            windowID,
            reservation: reservation,
            submitConstraints: submitConstraints,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            damage: damage,
            draw
        )
    }

    package func cancelSoftwareFrameReservation(
        _ windowID: WindowID,
        reservation: SoftwareFrameReservation
    ) throws {
        try requireCore().cancelSoftwareFrameReservation(windowID, reservation: reservation)
    }
}
