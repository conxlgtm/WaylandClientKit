import WaylandRaw

extension DisplayCore {
    func beginActivationTokenRequest(
        _ request: ActivationTokenRequestPlan
    ) throws -> PendingActivationTokenRequest {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw ActivationError.displayClosed
            }

            let surface = try request.windowID.map { windowID in
                try activationWindowSurface(windowID)
            }

            return try requireSession().beginActivationTokenRequestOnOwnerThread(
                request,
                surface: surface
            )
        }
    }

    func activateWindow(_ windowID: WindowID, token: ActivationToken) throws {
        try withFatalFailureFinalization {
            let surface = try activationWindowSurface(windowID)
            try requireSession().activateOnOwnerThread(token: token, surface: surface)
        }
    }

    func cancelActivationTokenRequest(
        _ requestID: ActivationRequestID,
        error: ActivationError
    ) {
        guard let activeSession else { return }

        activeSession.cancelActivationTokenRequestOnOwnerThread(requestID, error: error)
    }

    private func activationWindowSurface(_ windowID: WindowID) throws -> RawSurface {
        guard !isClosed else {
            throw ActivationError.displayClosed
        }
        guard let window = surfaces.window(windowID) else {
            throw ActivationError.unknownWindow(windowID)
        }
        guard !window.isClosedOnOwnerThread else {
            throw ActivationError.closedWindow(windowID)
        }

        return window.rawSurfaceOnOwnerThread
    }
}
