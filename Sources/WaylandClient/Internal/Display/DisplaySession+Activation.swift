import WaylandRaw

extension DisplaySession {
    package func beginActivationTokenRequestOnOwnerThread(
        _ request: ActivationTokenRequestPlan,
        surface: RawSurface?
    ) throws -> PendingActivationTokenRequest {
        connection.preconditionIsOwnerThread()
        let seat = try activationSeatOnOwnerThread(
            serialContext: request.serialContext
        )

        return try activationManager.beginTokenRequest(
            appID: request.appID,
            surface: surface,
            seat: seat,
            serial: request.serialContext?.serial
        )
    }

    package func activateOnOwnerThread(
        token: ActivationToken,
        surface: RawSurface
    ) throws {
        connection.preconditionIsOwnerThread()
        try activationManager.activate(token: token, surface: surface)
    }

    package func cancelActivationTokenRequestOnOwnerThread(
        _ requestID: ActivationRequestID,
        error: ActivationError
    ) {
        connection.preconditionIsOwnerThread()
        activationManager.cancelTokenRequest(requestID, error: error)
    }

    private func activationSeatOnOwnerThread(
        serialContext: ActivationSerialContext?
    ) throws -> RawSeat? {
        connection.preconditionIsOwnerThread()
        guard let serialContext else { return nil }

        let globals = try connection.bindRequiredGlobals()
        guard let seat = globals.seatRegistry.seat(for: RawSeatID(serialContext.seatID)) else {
            throw ActivationError.unknownSeat(serialContext.seatID)
        }

        return seat
    }
}
