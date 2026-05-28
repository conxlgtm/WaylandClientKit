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

    package init(rawValue requestRawValue: UInt64) {
        rawValue = requestRawValue
    }
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

    package func completedResult() -> ActivationTokenResult? {
        state.withLock { tokenState in
            guard case .completed(let result) = tokenState else { return nil }

            return result
        }
    }

    @discardableResult
    package func complete(_ result: ActivationTokenResult) -> Bool {
        let completion =
            state.withLock { tokenState in
                switch tokenState {
                case .pending:
                    tokenState = .completed(result)
                    return (
                        waiter: nil as CheckedContinuation<ActivationTokenResult, Never>?,
                        didComplete: true
                    )
                case .waiting(let waiter):
                    tokenState = .completed(result)
                    return (waiter: waiter, didComplete: true)
                case .completed:
                    return (
                        waiter: nil as CheckedContinuation<ActivationTokenResult, Never>?,
                        didComplete: false
                    )
                }
            }

        completion.waiter?.resume(returning: result)
        return completion.didComplete
    }
}

private enum ActivationTokenRequestState {
    case pending
    case waiting(CheckedContinuation<Result<ActivationToken, ActivationError>, Never>)
    case completed(Result<ActivationToken, ActivationError>)
}

package final class ActivationManager {
    private let backend: any ActivationManagerBackend
    private var requestIDs = IDGenerator<ActivationRequestID>()
    private var pendingTokenRequests =
        DisplayResourceTable<ActivationRequestID, any ActivationTokenBinding>()
    private var pendingWaiters =
        DisplayResourceTable<ActivationRequestID, PendingActivationTokenRequest>()
    private var isShutDown = false

    package init(connection rawConnection: RawDisplayConnection) {
        backend = LiveActivationManagerBackend(connection: rawConnection)
    }

    package init(backend managerBackend: any ActivationManagerBackend) {
        managerBackend.preconditionIsOwnerThread()
        backend = managerBackend
    }

    package func beginTokenRequest(
        appID: ActivationAppID?,
        surface: RawSurface?,
        seat: RawSeat?,
        serial: InputSerial?
    ) throws -> PendingActivationTokenRequest {
        backend.preconditionIsOwnerThread()
        guard !isShutDown else {
            throw ActivationError.displayClosed
        }

        let requestID = makeRequestID()
        let pending = PendingActivationTokenRequest(id: requestID)
        try pendingWaiters.insert(pending, id: requestID)

        let tokenRequest: any ActivationTokenBinding
        do {
            tokenRequest = try backend.requestToken { [weak self, weak pending] tokenValue in
                do {
                    let token = try ActivationToken(tokenValue.value)
                    pending?.complete(.success(token))
                } catch {
                    pending?.complete(.failure(.invalidToken))
                }
                self?.finishTokenRequest(requestID)
            }
        } catch {
            _ = pendingWaiters.remove(requestID)
            throw error
        }

        guard pendingWaiters.get(requestID) != nil else {
            tokenRequest.destroy()
            return pending
        }

        if let appID {
            tokenRequest.setAppID(appID.value)
        }
        if let surface {
            tokenRequest.setSurface(surface)
        }
        if let seat, let serial {
            tokenRequest.setSerial(serial, seat: seat)
        }

        do {
            try pendingTokenRequests.insert(tokenRequest, id: requestID)
        } catch {
            tokenRequest.destroy()
            _ = pendingWaiters.remove(requestID)
            throw error
        }
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
        pendingTokenRequests.remove(requestID)?.cancel()
        pendingWaiters.remove(requestID)?.complete(.failure(error))
    }

    package func shutdown() {
        backend.preconditionIsOwnerThread()
        guard !isShutDown else { return }

        isShutDown = true
        let tokenRequests = pendingTokenRequests.removeAll()
        let waiters = pendingWaiters.removeAll()

        for tokenRequest in tokenRequests {
            tokenRequest.cancel()
        }
        for waiter in waiters {
            waiter.complete(.failure(.displayClosed))
        }
    }

    private func makeRequestID() -> ActivationRequestID {
        requestIDs.next()
    }

    private func finishTokenRequest(_ requestID: ActivationRequestID) {
        backend.preconditionIsOwnerThread()
        pendingTokenRequests.remove(requestID)?.destroy()
        _ = pendingWaiters.remove(requestID)
    }
}

extension RawXDGActivationToken: ActivationTokenBinding {
    package func setSerial(_ serial: InputSerial, seat: RawSeat) {
        setSerial(serial.rawValue, seat: seat)
    }
}
