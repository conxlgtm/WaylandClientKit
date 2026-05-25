extension WaylandDisplay {
    public static let defaultActivationTokenTimeoutMilliseconds: Int32 = 1_000

    public func requestActivationToken(
        _ request: ActivationTokenRequest = .init(),
        timeoutMilliseconds: Int32 = defaultActivationTokenTimeoutMilliseconds
    ) async throws -> ActivationToken {
        if let window = request.window, !window.isOwned(by: self) {
            throw ActivationError.foreignWindow(window.id)
        }

        let pending = try activationCore().beginActivationTokenRequest(
            ActivationTokenRequestPlan(request)
        )

        do {
            return try await Self.waitForActivationToken(
                pending,
                timeoutMilliseconds: timeoutMilliseconds
            )
        } catch let error as ActivationError {
            cancelActivationTokenRequest(pending.id, error: error)
            throw error
        } catch {
            cancelActivationTokenRequest(pending.id, error: .displayClosed)
            throw error
        }
    }

    public func activate(window: Window, token: ActivationToken) throws {
        guard window.isOwned(by: self) else {
            throw ActivationError.foreignWindow(window.id)
        }

        try activationCore().activateWindow(window.id, token: token)
    }

    private func activationCore() throws -> DisplayCore {
        do {
            return try requireCore()
        } catch ClientError.display(.closed) {
            throw ActivationError.displayClosed
        }
    }

    private func cancelActivationTokenRequest(
        _ requestID: ActivationRequestID,
        error: ActivationError
    ) {
        guard let core = try? requireCore() else { return }

        core.cancelActivationTokenRequest(requestID, error: error)
    }

    private static func waitForActivationToken(
        _ pending: PendingActivationTokenRequest,
        timeoutMilliseconds: Int32
    ) async throws -> ActivationToken {
        try await withThrowingTaskGroup(of: ActivationToken.self) { group in
            group.addTask {
                try await pending.value()
            }

            if timeoutMilliseconds >= 0 {
                group.addTask {
                    try await Task.sleep(for: .milliseconds(Int(timeoutMilliseconds)))
                    throw ActivationError.tokenRequestTimedOut
                }
            }

            guard let token = try await group.next() else {
                throw ActivationError.displayClosed
            }

            group.cancelAll()
            return token
        }
    }
}
