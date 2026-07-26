/// The terminal disposition of an asynchronously prepared software frame.
public enum SoftwarePresentationOutcome: Equatable, Sendable {
    /// The frame was committed to the window's Wayland surface.
    case presented
    /// Preparation completed after the transaction became stale or was canceled
    /// during final validation.
    case superseded
    /// No presentation started because redraw pacing or buffers deferred it.
    case deferred
    /// The window or its display closed before the frame could be committed.
    case closed
}

extension Window {
    @discardableResult
    public func show<Prepared: Sendable>(
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        requestPresentationFeedback: Bool = false,
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw: sending @Sendable (Prepared, borrowing SoftwareFrame) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        try await show(
            damage: nil,
            timeoutMilliseconds: timeoutMilliseconds,
            requestPresentationFeedback: requestPresentationFeedback,
            preparing: prepare,
            draw
        )
    }

    @discardableResult
    public func show<Prepared: Sendable>(
        damage: SurfaceDamageRegion?,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        requestPresentationFeedback: Bool = false,
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw: sending @Sendable (Prepared, borrowing SoftwareFrame) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        let reservationOutcome = try await display.reserveSoftwareFrameForShow(
            id,
            timeoutMilliseconds: timeoutMilliseconds
        )
        let reservation: SoftwareFrameReservation
        switch reservationOutcome {
        case .reserved(let reservedFrame):
            reservation = reservedFrame
        case .deferred:
            return .deferred
        case .closed:
            return .closed
        }

        do {
            let prepared = try await prepare(reservation)
            return try await display.submitReservedSoftwareFrame(
                id,
                reservation: reservation,
                submitConstraints: .default,
                metadata: .default,
                requestPresentationFeedback: requestPresentationFeedback,
                damage: damage
            ) { frame in
                try draw(prepared, frame)
            }
        } catch {
            let submissionError = error
            do {
                try await display.cancelSoftwareFrameReservation(id, reservation: reservation)
            } catch {
                throw submissionError
            }
            throw submissionError
        }
    }

    @discardableResult
    public func redraw<Prepared: Sendable>(
        requestPresentationFeedback: Bool = false,
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw: sending @Sendable (Prepared, borrowing SoftwareFrame) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        try await redraw(
            damage: nil,
            requestPresentationFeedback: requestPresentationFeedback,
            preparing: prepare,
            draw
        )
    }

    @discardableResult
    public func redraw<Prepared: Sendable>(
        damage: SurfaceDamageRegion?,
        requestPresentationFeedback: Bool = false,
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw: sending @Sendable (Prepared, borrowing SoftwareFrame) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        let reservationOutcome = try await display.reserveSoftwareFrameForRedraw(id)
        let reservation: SoftwareFrameReservation
        switch reservationOutcome {
        case .reserved(let reservedFrame):
            reservation = reservedFrame
        case .deferred:
            return .deferred
        case .closed:
            return .closed
        }

        do {
            let prepared = try await prepare(reservation)
            return try await display.submitReservedSoftwareFrame(
                id,
                reservation: reservation,
                submitConstraints: .default,
                metadata: .default,
                requestPresentationFeedback: requestPresentationFeedback,
                damage: damage
            ) { frame in
                try draw(prepared, frame)
            }
        } catch {
            let submissionError = error
            do {
                try await display.cancelSoftwareFrameReservation(id, reservation: reservation)
            } catch {
                throw submissionError
            }
            throw submissionError
        }
    }
}
