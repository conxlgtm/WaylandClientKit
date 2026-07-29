extension Subsurface {
    @discardableResult
    public func show(
        metadata: SurfaceFrameMetadata = .default,
        requestPresentationFeedback: Bool = false,
        _ draw:
            sending @Sendable (
                borrowing SoftwareFrame
            ) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        try await show(
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            preparing: { _ in () },
            { _, frame in try draw(frame) }
        )
    }

    @discardableResult
    public func show<Prepared: Sendable>(
        metadata: SurfaceFrameMetadata = .default,
        requestPresentationFeedback: Bool = false,
        preparing:
            sending @Sendable (
                SoftwareFrameReservation
            ) async throws -> Prepared,
        _ draw:
            sending @Sendable (
                Prepared,
                borrowing SoftwareFrame
            ) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        switch try await display.reserveSubsurfaceSoftwareFrameForShow(
            id: subsurfaceID,
            metadata: metadata
        ) {
        case .reserved(let reservation):
            let prepared: Prepared
            do {
                prepared = try await preparing(reservation)
            } catch {
                let submissionError = error
                do {
                    try await display.cancelReservedSubsurfaceSoftwareFrame(
                        id: subsurfaceID,
                        reservation: reservation
                    )
                } catch {
                    throw submissionError
                }
                throw submissionError
            }
            return try await display.submitReservedSubsurfaceSoftwareFrame(
                id: subsurfaceID,
                reservation: reservation,
                metadata: metadata,
                requestPresentationFeedback: requestPresentationFeedback,
                prepared: prepared,
                draw
            )
        case .deferred:
            return .deferred
        case .closed:
            return .closed
        }
    }

    @discardableResult
    public func redraw(
        metadata: SurfaceFrameMetadata = .default,
        requestPresentationFeedback: Bool = false,
        _ draw:
            sending @Sendable (
                borrowing SoftwareFrame
            ) throws -> Void
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
        preparing:
            sending @Sendable (
                SoftwareFrameReservation
            ) async throws -> Prepared,
        _ draw:
            sending @Sendable (
                Prepared,
                borrowing SoftwareFrame
            ) throws -> Void
    ) async throws -> SoftwarePresentationOutcome {
        switch try await display.reserveSubsurfaceSoftwareFrameForRedraw(
            id: subsurfaceID,
            metadata: metadata
        ) {
        case .reserved(let reservation):
            let prepared: Prepared
            do {
                prepared = try await preparing(reservation)
            } catch {
                let submissionError = error
                do {
                    try await display.cancelReservedSubsurfaceSoftwareFrame(
                        id: subsurfaceID,
                        reservation: reservation
                    )
                } catch {
                    throw submissionError
                }
                throw submissionError
            }
            return try await display.submitReservedSubsurfaceSoftwareFrame(
                id: subsurfaceID,
                reservation: reservation,
                metadata: metadata,
                requestPresentationFeedback: requestPresentationFeedback,
                prepared: prepared,
                draw
            )
        case .deferred:
            return .deferred
        case .closed:
            return .closed
        }
    }
}
