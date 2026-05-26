import Synchronization
import WaylandRaw

package typealias ActivationTokenResult = Result<ActivationToken, ActivationError>

package protocol ActivationTokenBinding: AnyObject {
    func setAppID(_ appID: String)
    func setSurface(_ surface: RawSurface)
    func setSerial(_ serial: InputSerial, seat: RawSeat)
    func commit()
    func cancel()
    func destroy()
}

package protocol ActivationManagerBackend: AnyObject {
    func preconditionIsOwnerThread()
    func requestToken(
        onDone: @escaping (RawXDGActivationTokenValue) -> Void
    ) throws -> any ActivationTokenBinding
    func activate(token: ActivationToken, surface: RawSurface) throws
}

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
            let immediate: ActivationTokenResult? = state.withLock { tokenState in
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

    package func complete(_ result: ActivationTokenResult) {
        let waiter: CheckedContinuation<ActivationTokenResult, Never>? =
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
    private let backend: any ActivationManagerBackend
    private var nextRequestID: UInt64 = 1
    private var pendingTokenRequests: [ActivationRequestID: any ActivationTokenBinding] = [:]
    private var pendingWaiters: [ActivationRequestID: PendingActivationTokenRequest] = [:]
    private var isShutDown = false

    package init(connection rawConnection: RawDisplayConnection) {
        backend = LiveActivationManagerBackend(connection: rawConnection)
    }

    package init(backend managerBackend: any ActivationManagerBackend) {
        managerBackend.preconditionIsOwnerThread()
        backend = managerBackend
    }

    package func beginTokenRequest(
        appID: String?,
        surface: RawSurface?,
        seat: RawSeat?,
        serial: InputSerial?
    ) throws -> PendingActivationTokenRequest {
        backend.preconditionIsOwnerThread()
        guard !isShutDown else {
            throw ActivationError.displayClosed
        }

        try validate(appID: appID, seat: seat, serial: serial)
        let requestID = makeRequestID()
        let pending = PendingActivationTokenRequest(id: requestID)
        let tokenRequest = try backend.requestToken { [weak self, weak pending] tokenValue in
            do {
                let token = try ActivationToken(tokenValue.value)
                pending?.complete(.success(token))
            } catch {
                pending?.complete(.failure(.invalidToken))
            }
            self?.finishTokenRequest(requestID)
        }

        if let appID {
            tokenRequest.setAppID(appID)
        }
        if let surface {
            tokenRequest.setSurface(surface)
        }
        if let seat, let serial {
            tokenRequest.setSerial(serial, seat: seat)
        }

        pendingTokenRequests[requestID] = tokenRequest
        pendingWaiters[requestID] = pending
        tokenRequest.commit()
        return pending
    }

    package func activate(token: ActivationToken, surface: RawSurface) throws {
        backend.preconditionIsOwnerThread()
        guard !isShutDown else {
            throw ActivationError.displayClosed
        }

        try backend.activate(token: token, surface: surface)
    }

    package func cancelTokenRequest(
        _ requestID: ActivationRequestID,
        error: ActivationError
    ) {
        backend.preconditionIsOwnerThread()
        pendingTokenRequests.removeValue(forKey: requestID)?.cancel()
        pendingWaiters.removeValue(forKey: requestID)?.complete(.failure(error))
    }

    package func shutdown() {
        backend.preconditionIsOwnerThread()
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
        backend.preconditionIsOwnerThread()
        pendingTokenRequests.removeValue(forKey: requestID)?.destroy()
        pendingWaiters.removeValue(forKey: requestID)
    }
}

extension RawXDGActivationToken: ActivationTokenBinding {
    package func setSerial(_ serial: InputSerial, seat: RawSeat) {
        setSerial(serial.rawValue, seat: seat)
    }
}
