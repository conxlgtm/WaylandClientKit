import Synchronization
import WaylandRaw

package struct ActivationRequestID: Hashable, Sendable {
    package let rawValue: UInt64
}

package final class PendingActivationTokenRequest: Sendable {
    package let id: ActivationRequestID

    private let state = Mutex<ActivationTokenRequestState>(.pending)

    package init(id requestID: ActivationRequestID) {
        id = requestID
    }

    package func value() async throws -> ActivationToken {
        let result = await withCheckedContinuation { continuation in
            let immediate: Result<ActivationToken, ActivationError>? = state.withLock {
                tokenState in
                switch tokenState {
                case .pending:
                    tokenState = .waiting(continuation)
                    return nil
                case .waiting:
                    preconditionFailure("activation token request awaited more than once")
                case .completed(let result):
                    return result
                }
            }

            if let immediate {
                continuation.resume(returning: immediate)
            }
        }

        return try result.get()
    }

    package func complete(_ result: Result<ActivationToken, ActivationError>) {
        let waiter: CheckedContinuation<Result<ActivationToken, ActivationError>, Never>? =
            state.withLock { tokenState in
            switch tokenState {
            case .pending:
                tokenState = .completed(result)
                return nil
            case .waiting(let waiter):
                tokenState = .completed(result)
                return waiter
            case .completed:
                return nil
            }
        }

        waiter?.resume(returning: result)
    }
}

private enum ActivationTokenRequestState {
    case pending
    case waiting(CheckedContinuation<Result<ActivationToken, ActivationError>, Never>)
    case completed(Result<ActivationToken, ActivationError>)
}

package final class ActivationManager {
    private let connection: RawDisplayConnection
    private var nextRequestID: UInt64 = 1
    private var pendingTokenRequests: [ActivationRequestID: RawXDGActivationToken] = [:]
    private var pendingWaiters: [ActivationRequestID: PendingActivationTokenRequest] = [:]
    private var isShutDown = false

    package init(connection rawConnection: RawDisplayConnection) {
        connection = rawConnection
    }

    package func beginTokenRequest(
        appID: String?,
        surface: RawSurface?,
        seat: RawSeat?,
        serial: InputSerial?
    ) throws -> PendingActivationTokenRequest {
        connection.preconditionIsOwnerThread()
        guard !isShutDown else {
            throw ActivationError.displayClosed
        }

        try validate(appID: appID, seat: seat, serial: serial)
        let activation = try activationGlobal()
        let requestID = makeRequestID()
        let pending = PendingActivationTokenRequest(id: requestID)
        let tokenRequest = try activation.requestToken { [weak self, weak pending] tokenValue in
            let token = ActivationToken(unchecked: tokenValue.value)
            pending?.complete(.success(token))
            self?.finishTokenRequest(requestID)
        }

        if let appID {
            tokenRequest.setAppID(appID)
        }
        if let surface {
            tokenRequest.setSurface(surface)
        }
        if let seat, let serial {
            tokenRequest.setSerial(serial.rawValue, seat: seat)
        }

        pendingTokenRequests[requestID] = tokenRequest
        pendingWaiters[requestID] = pending
        tokenRequest.commit()
        return pending
    }

    package func activate(token: ActivationToken, surface: RawSurface) throws {
        connection.preconditionIsOwnerThread()
        guard !isShutDown else {
            throw ActivationError.displayClosed
        }

        try activationGlobal().activate(
            token: RawXDGActivationTokenValue(token.value),
            surface: surface
        )
    }

    package func cancelTokenRequest(
        _ requestID: ActivationRequestID,
        error: ActivationError
    ) {
        connection.preconditionIsOwnerThread()
        pendingTokenRequests.removeValue(forKey: requestID)?.cancel()
        pendingWaiters.removeValue(forKey: requestID)?.complete(.failure(error))
    }

    package func shutdown() {
        connection.preconditionIsOwnerThread()
        guard !isShutDown else { return }

        isShutDown = true
        let tokenRequests = pendingTokenRequests
        let waiters = pendingWaiters
        pendingTokenRequests.removeAll()
        pendingWaiters.removeAll()

        for tokenRequest in tokenRequests.values {
            tokenRequest.cancel()
        }
        for waiter in waiters.values {
            waiter.complete(.failure(.displayClosed))
        }
    }

    private func activationGlobal() throws -> RawXDGActivation {
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let activation) = globals.extensions.xdgActivation else {
            throw ActivationError.unavailable
        }

        return activation
    }

    private func validate(appID: String?, seat: RawSeat?, serial: InputSerial?) throws {
        if let appID {
            guard !appID.isEmpty, !appID.contains("\0") else {
                throw ActivationError.invalidAppID
            }
        }

        switch (seat, serial) {
        case (.some, .some), (.none, .none):
            return
        case (.some, .none), (.none, .some):
            throw ActivationError.incompleteSerialContext
        }
    }

    private func makeRequestID() -> ActivationRequestID {
        defer { nextRequestID += 1 }
        return ActivationRequestID(rawValue: nextRequestID)
    }

    private func finishTokenRequest(_ requestID: ActivationRequestID) {
        connection.preconditionIsOwnerThread()
        pendingTokenRequests.removeValue(forKey: requestID)?.destroy()
        pendingWaiters.removeValue(forKey: requestID)
    }
}
