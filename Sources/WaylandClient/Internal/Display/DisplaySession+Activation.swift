import WaylandRaw

extension DisplaySession {
    package func beginActivationTokenRequestOnOwnerThread(
        _ request: ActivationTokenRequestPlan,
        surface: RawSurface?
    ) throws -> PendingActivationTokenRequest {
        connection.preconditionIsOwnerThread()
        let seat = try activationSeatOnOwnerThread(
            seatID: request.seatID,
            serial: request.serial
        )

        return try activationManager.beginTokenRequest(
            appID: request.appID,
            surface: surface,
            seat: seat,
            serial: request.serial
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
        seatID: SeatID?,
        serial: InputSerial?
    ) throws -> RawSeat? {
        connection.preconditionIsOwnerThread()

        switch (seatID, serial) {
        case (.none, .none):
            return nil
        case (.none, .some), (.some, .none):
            throw ActivationError.incompleteSerialContext
        case (.some(let seatID), .some):
            let globals = try connection.bindRequiredGlobals()
            guard let seat = globals.seatRegistry.seat(for: RawSeatID(seatID)) else {
                throw ActivationError.unknownSeat(seatID)
            }

            return seat
        }
    }
}
