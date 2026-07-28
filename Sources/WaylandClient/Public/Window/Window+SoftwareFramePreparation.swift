/// The terminal disposition of a managed-surface software frame.
public enum SoftwarePresentationOutcome: Equatable, Sendable {
    /// The frame was committed through the managed surface's role boundary.
    case presented
    /// Preparation completed after the transaction became stale or was canceled
    /// during final validation.
    case superseded
    /// No presentation started because redraw pacing or buffers deferred it.
    case deferred
    /// The managed surface, its parent, or its display closed before commit.
    case closed
}

extension Window {
    @discardableResult
    public func show(
        metadata frameMetadata: SurfaceFrameMetadata = .default,
        requestPresentationFeedback: Bool = false,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        try await show(
            metadata: frameMetadata,
            requestPresentationFeedback: requestPresentationFeedback,
            timeoutMilliseconds: timeoutMilliseconds,
            preparing: { _ in () },
            { _, frame in
                try draw(frame)
            }
        )
    }

    @discardableResult
    public func show<Prepared: Sendable>(
        metadata frameMetadata: SurfaceFrameMetadata = .default,
        requestPresentationFeedback: Bool = false,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw:
            sending @Sendable (
                Prepared,
                borrowing SoftwareFrame
            ) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        let reservationOutcome = try await display.reserveSoftwareFrameForShow(
            id,
            timeoutMilliseconds: timeoutMilliseconds,
            metadata: frameMetadata
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
                metadata: frameMetadata,
                requestPresentationFeedback: requestPresentationFeedback,
                damage: frameMetadata.damage
            ) { frame in
                try draw(prepared, frame)
            }
        } catch {
            let submissionError = error
            let callerError =
                (submissionError as? SoftwareSurfaceDrawFailure)?.underlying
                ?? submissionError
            do {
                try await display.cancelSoftwareFrameReservation(id, reservation: reservation)
            } catch {
                throw callerError
            }
            throw callerError
        }
    }

    @discardableResult
    public func redraw(
        metadata frameMetadata: SurfaceFrameMetadata = .default,
        requestPresentationFeedback: Bool = false,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        try await redraw(
            metadata: frameMetadata,
            requestPresentationFeedback: requestPresentationFeedback,
            preparing: { _ in () },
            { _, frame in
                try draw(frame)
            }
        )
    }

    @discardableResult
    public func redraw<Prepared: Sendable>(
        metadata frameMetadata: SurfaceFrameMetadata = .default,
        requestPresentationFeedback: Bool = false,
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw:
            sending @Sendable (
                Prepared,
                borrowing SoftwareFrame
            ) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        let reservationOutcome = try await display.reserveSoftwareFrameForRedraw(
            id,
            metadata: frameMetadata
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
                metadata: frameMetadata,
                requestPresentationFeedback: requestPresentationFeedback,
                damage: frameMetadata.damage
            ) { frame in
                try draw(prepared, frame)
            }
        } catch {
            let submissionError = error
            let callerError =
                (submissionError as? SoftwareSurfaceDrawFailure)?.underlying
                ?? submissionError
            do {
                try await display.cancelSoftwareFrameReservation(id, reservation: reservation)
            } catch {
                throw callerError
            }
            throw callerError
        }
    }
}
