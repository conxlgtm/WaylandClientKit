extension Window {
    public func show<Prepared: Sendable>(
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw: sending @Sendable (Prepared, borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await show(
            damage: nil,
            timeoutMilliseconds: timeoutMilliseconds,
            preparing: prepare,
            draw
        )
    }

    public func show<Prepared: Sendable>(
        damage: SurfaceDamageRegion?,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw: sending @Sendable (Prepared, borrowing SoftwareFrame) throws -> Void
    ) async throws {
        guard
            let reservation = try await display.reserveSoftwareFrameForShow(
                id,
                timeoutMilliseconds: timeoutMilliseconds
            )
        else {
            return
        }

        do {
            let prepared = try await prepare(reservation)
            try await display.submitReservedSoftwareFrame(
                id,
                reservation: reservation,
                submitConstraints: .default,
                metadata: .default,
                requestPresentationFeedback: false,
                damage: damage
            ) { frame in
                try draw(prepared, frame)
            }
        } catch {
            try? await display.cancelSoftwareFrameReservation(id, reservation: reservation)
            throw error
        }
    }

    public func redraw<Prepared: Sendable>(
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw: sending @Sendable (Prepared, borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await redraw(
            damage: nil,
            preparing: prepare,
            draw
        )
    }

    public func redraw<Prepared: Sendable>(
        damage: SurfaceDamageRegion?,
        preparing prepare: sending @Sendable (SoftwareFrameReservation) async throws -> Prepared,
        _ draw: sending @Sendable (Prepared, borrowing SoftwareFrame) throws -> Void
    ) async throws {
        guard let reservation = try await display.reserveSoftwareFrameForRedraw(id) else {
            return
        }

        do {
            let prepared = try await prepare(reservation)
            try await display.submitReservedSoftwareFrame(
                id,
                reservation: reservation,
                submitConstraints: .default,
                metadata: .default,
                requestPresentationFeedback: false,
                damage: damage
            ) { frame in
                try draw(prepared, frame)
            }
        } catch {
            try? await display.cancelSoftwareFrameReservation(id, reservation: reservation)
            throw error
        }
    }
}
