extension PopupSurface {
    @discardableResult
    public func show(
        metadata: SurfaceFrameMetadata = .default,
        requestPresentationFeedback: Bool = false,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        try await show(
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            timeoutMilliseconds: timeoutMilliseconds,
            preparing: { _ in () },
            { _, frame in try draw(frame) }
        )
    }

    @discardableResult
    public func show<Prepared: Sendable>(
        metadata: SurfaceFrameMetadata = .default,
        requestPresentationFeedback: Bool = false,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw: sending @Sendable (Prepared, borrowing SoftwareFrame) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        let reservationOutcome = try await display.reservePopupSoftwareFrameForShow(
            id: popupID,
            timeoutMilliseconds: timeoutMilliseconds,
            metadata: metadata
        )
        switch reservationOutcome {
        case .deferred:
            return .deferred
        case .closed:
            return .closed
        case .reserved(let reservation):
            do {
                let prepared = try await prepare(reservation)
                return try await display.submitReservedPopupSoftwareFrame(
                    id: popupID,
                    reservation: reservation,
                    metadata: metadata,
                    requestPresentationFeedback: requestPresentationFeedback
                ) { frame in
                    try draw(prepared, frame)
                }
            } catch {
                let submissionError = error
                do {
                    try await display.cancelReservedPopupSoftwareFrame(
                        id: popupID,
                        reservation: reservation
                    )
                } catch {
                    throw submissionError
                }
                throw submissionError
            }
        }
    }

    @discardableResult
    public func redraw(
        metadata: SurfaceFrameMetadata = .default,
        requestPresentationFeedback: Bool = false,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        try await redraw(
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            preparing: { _ in () },
            { _, frame in try draw(frame) }
        )
    }

    @discardableResult
    public func redraw<Prepared: Sendable>(
        metadata: SurfaceFrameMetadata = .default,
        requestPresentationFeedback: Bool = false,
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw: sending @Sendable (Prepared, borrowing SoftwareFrame) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        let reservationOutcome = try await display.reservePopupSoftwareFrameForRedraw(
            id: popupID,
            metadata: metadata
        )
        switch reservationOutcome {
        case .deferred:
            return .deferred
        case .closed:
            return .closed
        case .reserved(let reservation):
            do {
                let prepared = try await prepare(reservation)
                return try await display.submitReservedPopupSoftwareFrame(
                    id: popupID,
                    reservation: reservation,
                    metadata: metadata,
                    requestPresentationFeedback: requestPresentationFeedback
                ) { frame in
                    try draw(prepared, frame)
                }
            } catch {
                let submissionError = error
                do {
                    try await display.cancelReservedPopupSoftwareFrame(
                        id: popupID,
                        reservation: reservation
                    )
                } catch {
                    throw submissionError
                }
                throw submissionError
            }
        }
    }
}
