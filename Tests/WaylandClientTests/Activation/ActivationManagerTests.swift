import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct ActivationManagerTests {
    @Test
    func tokenDoneResolvesPendingRequest() async throws {
        let backend = RecordingActivationBackend()
        let manager = ActivationManager(backend: backend)

        let pending = try manager.beginTokenRequest(
            appID: try ActivationAppID("org.waylandclientkit.Test"),
            surface: nil,
            seat: nil,
            serial: nil
        )
        backend.emitDone("opaque-token")

        let token = try await pending.value()

        #expect(token == ActivationToken(unchecked: "opaque-token"))
        #expect(
            backend.latestBinding?.operations == [
                .setAppID("org.waylandclientkit.Test"),
                .commit,
                .destroy,
            ]
        )
    }

    @Test
    func invalidTokenDoneFailsPendingRequestAndDestroysBinding() async throws {
        let backend = RecordingActivationBackend()
        let manager = ActivationManager(backend: backend)

        let pending = try manager.beginTokenRequest(
            appID: nil,
            surface: nil,
            seat: nil,
            serial: nil
        )
        backend.emitDone("")

        let error = await activationError {
            _ = try await pending.value()
        }

        #expect(error == .invalidToken)
        #expect(backend.latestBinding?.operations == [.commit, .destroy])
    }

    @Test
    func synchronousTokenDoneDuringRequestDoesNotLeavePendingBinding() async throws {
        let backend = RecordingActivationBackend()
        backend.synchronousDoneTokenValue = "sync-token"
        let manager = ActivationManager(backend: backend)

        let pending = try manager.beginTokenRequest(
            appID: try ActivationAppID("org.waylandclientkit.Test"),
            surface: nil,
            seat: nil,
            serial: nil
        )
        let token = try await pending.value()

        manager.cancelTokenRequest(pending.id, error: .tokenRequestTimedOut)

        #expect(token == ActivationToken(unchecked: "sync-token"))
        #expect(backend.latestBinding?.operations == [.destroy])
    }

    @Test
    func zeroTimeoutWaitReturnsAlreadyCompletedToken() async throws {
        let pending = PendingActivationTokenRequest(id: ActivationRequestID(rawValue: 1))
        pending.complete(.success(ActivationToken(unchecked: "ready-token")))

        let token = try await WaylandDisplay.waitForActivationToken(
            pending,
            timeoutMilliseconds: 0
        )

        #expect(token == ActivationToken(unchecked: "ready-token"))
    }

    @Test
    func zeroTimeoutWaitCancelsPendingRequest() async throws {
        let pending = PendingActivationTokenRequest(id: ActivationRequestID(rawValue: 1))

        let error = await activationError {
            _ = try await WaylandDisplay.waitForActivationToken(
                pending,
                timeoutMilliseconds: 0
            )
        }

        #expect(error == .tokenRequestTimedOut)
        let completedError = await activationError {
            guard let result = pending.completedResult() else {
                Issue.record("expected completed activation token request")
                return
            }

            _ = try result.get()
        }

        #expect(completedError == .tokenRequestTimedOut)
    }

    @Test
    func positiveTimeoutWaitCancelsPendingRequestBeforeReturning() async throws {
        let pending = PendingActivationTokenRequest(id: ActivationRequestID(rawValue: 1))

        let error = await activationError {
            _ = try await WaylandDisplay.waitForActivationToken(
                pending,
                timeoutMilliseconds: 1
            )
        }

        #expect(error == .tokenRequestTimedOut)
        let completedError = await activationError {
            guard let result = pending.completedResult() else {
                Issue.record("expected completed activation token request")
                return
            }

            _ = try result.get()
        }

        #expect(completedError == .tokenRequestTimedOut)
    }

    @Test
    func completedResultReportsAlreadyFinishedRequest() throws {
        let pending = PendingActivationTokenRequest(id: ActivationRequestID(rawValue: 1))
        #expect(pending.completedResult() == nil)

        pending.complete(.success(ActivationToken(unchecked: "ready-token")))

        #expect(
            try pending.completedResult()?.get()
                == ActivationToken(unchecked: "ready-token")
        )
    }

    @Test
    func unavailableBackendErrorIsPreserved() {
        let backend = RecordingActivationBackend()
        backend.requestError = ActivationError.unavailable
        let manager = ActivationManager(backend: backend)

        #expect(throws: ActivationError.unavailable) {
            _ = try manager.beginTokenRequest(
                appID: nil,
                surface: nil,
                seat: nil,
                serial: nil
            )
        }
    }

    @Test
    func cancelPendingRequestDestroysBindingAndFailsWaiter() async throws {
        let backend = RecordingActivationBackend()
        let manager = ActivationManager(backend: backend)
        let pending = try manager.beginTokenRequest(
            appID: nil,
            surface: nil,
            seat: nil,
            serial: nil
        )

        manager.cancelTokenRequest(pending.id, error: .tokenRequestTimedOut)

        let error = await activationError {
            _ = try await pending.value()
        }
        #expect(error == .tokenRequestTimedOut)
        #expect(backend.latestBinding?.operations == [.commit, .cancel])
    }

    @Test
    func taskCancellationCompletesPendingRequestAsCancelled() async throws {
        let pending = PendingActivationTokenRequest(id: ActivationRequestID(rawValue: 2))
        let error = await activationError {
            try await withThrowingTaskGroup(of: ActivationToken.self) { group in
                group.addTask {
                    try await WaylandDisplay.waitForActivationToken(
                        pending,
                        timeoutMilliseconds: -1
                    )
                }
                group.cancelAll()
                _ = try await group.next()
            }
        }
        #expect(error == .cancelled)
        let completedError = await activationError {
            guard let result = pending.completedResult() else {
                Issue.record("expected completed activation token request")
                return
            }

            _ = try result.get()
        }
        #expect(completedError == .cancelled)
    }

    @Test
    func lateDoneAfterTaskCancellationIsIgnored() async throws {
        let backend = RecordingActivationBackend()
        let manager = ActivationManager(backend: backend)
        let pending = try manager.beginTokenRequest(
            appID: nil,
            surface: nil,
            seat: nil,
            serial: nil
        )

        manager.cancelTokenRequest(pending.id, error: .cancelled)
        backend.emitDone("late-token")

        let error = await activationError {
            _ = try await pending.value()
        }
        #expect(error == .cancelled)
        #expect(backend.latestBinding?.operations == [.commit, .cancel])
    }

    @Test
    func shutdownCancelsPendingRequestsAndIsIdempotent() async throws {
        let backend = RecordingActivationBackend()
        let manager = ActivationManager(backend: backend)
        let pending = try manager.beginTokenRequest(
            appID: nil,
            surface: nil,
            seat: nil,
            serial: nil
        )

        manager.shutdown()
        manager.shutdown()

        let error = await activationError {
            _ = try await pending.value()
        }
        #expect(error == .displayClosed)
        #expect(backend.latestBinding?.operations == [.commit, .cancel])
    }

    @Test
    func lateDoneAfterCancelDoesNotReplaceFailure() async throws {
        let backend = RecordingActivationBackend()
        let manager = ActivationManager(backend: backend)
        let pending = try manager.beginTokenRequest(
            appID: nil,
            surface: nil,
            seat: nil,
            serial: nil
        )

        manager.cancelTokenRequest(pending.id, error: .tokenRequestTimedOut)
        backend.emitDone("late-token")

        let error = await activationError {
            _ = try await pending.value()
        }
        #expect(error == .tokenRequestTimedOut)
    }
}

private func activationError(
    _ body: () async throws -> Void
) async -> ActivationError? {
    do {
        try await body()
        return nil
    } catch let error as ActivationError {
        return error
    } catch {
        Issue.record("unexpected error: \(error)")
        return nil
    }
}

private final class RecordingActivationBackend: ActivationManagerBackend {
    var requestCount = 0
    var requestError: (any Error)?
    var synchronousDoneTokenValue: String?
    private(set) var latestBinding: RecordingActivationTokenBinding?
    private var onDone: ((RawXDGActivationTokenValue) -> Void)?

    func preconditionIsOwnerThread() {
        // Test backend has no thread-affinity boundary.
    }

    func requestToken(
        onDone handler: @escaping (RawXDGActivationTokenValue) -> Void
    ) throws -> any ActivationTokenBinding {
        requestCount += 1
        if let requestError {
            throw requestError
        }

        let binding = RecordingActivationTokenBinding()
        latestBinding = binding
        onDone = handler
        if let synchronousDoneTokenValue {
            handler(RawXDGActivationTokenValue(synchronousDoneTokenValue))
        }
        return binding
    }

    func activate(token _: ActivationToken, surface _: RawSurface) throws {
        // Activation request forwarding uses live raw surfaces and is covered by compile tests.
    }

    func emitDone(_ tokenValue: String) {
        onDone?(RawXDGActivationTokenValue(tokenValue))
    }
}

private final class RecordingActivationTokenBinding: ActivationTokenBinding {
    enum Operation: Equatable {
        case setAppID(String)
        case setSurface
        case setSerial(InputSerial)
        case commit
        case cancel
        case destroy
    }

    private(set) var operations: [Operation] = []

    func setAppID(_ appID: String) {
        operations.append(.setAppID(appID))
    }

    func setSurface(_: RawSurface) {
        operations.append(.setSurface)
    }

    func setSerial(_ serial: InputSerial, seat _: RawSeat) {
        operations.append(.setSerial(serial))
    }

    func commit() {
        operations.append(.commit)
    }

    func cancel() {
        operations.append(.cancel)
    }

    func destroy() {
        operations.append(.destroy)
    }
}
