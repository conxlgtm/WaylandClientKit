import Foundation
import Testing
import WaylandRaw
import WaylandRuntime

@testable import WaylandClient

@Suite(
    .enabled(
        if: ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"]?.isEmpty == false
            && ProcessInfo.processInfo.environment[
                "WAYLAND_CLIENT_KIT_ENABLE_CONNECTION_LIFETIME_TESTS"] == "1",
        "Set WAYLAND_DISPLAY and WAYLAND_CLIENT_KIT_ENABLE_CONNECTION_LIFETIME_TESTS=1"
    ),
    .timeLimit(.minutes(1)),
    .serialized
)
struct WaylandDisplayScopedConnectionTests {
    @Test(arguments: ScopedConnectionExit.allCases)
    func closeFinishesBeforeScopeReturns(exit: ScopedConnectionExit) async throws {
        let probe = ScopedConnectionCloseProbe()
        // Observe close while this task waits in its window-close observer.
        // swiftlint:disable:next no_unstructured_task
        let operation = Task { try await exerciseScopedConnection(exit: exit, probe: probe) }
        defer {
            operation.cancel()
            await probe.resumeObserver()
            _ = await operation.result
        }

        let observation = try #require(await probe.waitForObserver())
        #expect(!observation.isClosed)
        #expect(observation.onOwnerThread)
        #expect(observation.wasCancelled == (exit == .cancelled))
        #expect(await probe.history == [.body, .observerEntered])

        await probe.resumeObserver()
        let result = await operation.result
        switch (exit, result) {
        case (.returned, .success(let value)):
            #expect(value == 42)
        case (.threw, .failure(let error)):
            #expect(error as? ScopedConnectionBodyError == .expected)
        case (.cancelled, .failure(let error)):
            #expect(error is CancellationError)
        default:
            Issue.record("Unexpected scoped connection result: \(result)")
        }
        #expect(await observation.display.isClosed)
        #expect(await scopedConnectionIsOnOwnerThread(observation.display))
        #expect(
            await probe.history == [.body, .observerEntered, .observerReturned, .scopeFinished])
    }
}

private func exerciseScopedConnection(
    exit: ScopedConnectionExit,
    probe: ScopedConnectionCloseProbe
) async throws -> Int {
    do {
        let result = try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.ScopedConnectionTests",
            cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
            discoveryTimeoutMilliseconds: 5_000
        ) { display in
            let window = try await display.createTopLevelWindow(
                configuration: WindowConfiguration(initialWidth: 16, initialHeight: 16)
            )
            try await window.show { frame in
                frame.withXRGB8888Rows { _, pixels in
                    for index in 0..<pixels.count {
                        pixels[index] = 0x0020_4060
                    }
                }
            }
            await display.registerWindowCloseObserver(for: window.id) {
                let observation = await scopedConnectionCloseObservation(display)
                await probe.observeClose(observation)
            }
            await probe.recordBody()
            switch exit {
            case .returned:
                return 42
            case .threw:
                throw ScopedConnectionBodyError.expected
            case .cancelled:
                unsafe withUnsafeCurrentTask { task in
                    unsafe task?.cancel()
                }
                throw CancellationError()
            }
        }
        await probe.recordScopeFinished()
        return result
    } catch {
        await probe.recordScopeFinished()
        throw error
    }
}

enum ScopedConnectionExit: CaseIterable, Sendable {
    case returned, threw, cancelled
}

private enum ScopedConnectionBodyError: Error {
    case expected
}

private enum ScopedConnectionEvent: Equatable, Sendable {
    case body, observerEntered, observerReturned, scopeFinished
}

private struct ScopedConnectionCloseObservation: Sendable {
    let display: WaylandDisplay
    let isClosed: Bool
    let onOwnerThread: Bool
    let wasCancelled: Bool
}

private actor ScopedConnectionCloseProbe {
    private(set) var history: [ScopedConnectionEvent] = []
    private var observation: ScopedConnectionCloseObservation?
    private var observationWaiter: CheckedContinuation<ScopedConnectionCloseObservation?, Never>?
    private var observerWaiter: CheckedContinuation<Void, Never>?
    private var observerMayReturn = false
    private var scopeFinished = false

    func recordBody() {
        history.append(.body)
    }

    func observeClose(_ value: ScopedConnectionCloseObservation) async {
        history.append(.observerEntered)
        observation = value
        observationWaiter?.resume(returning: value)
        observationWaiter = nil
        if !observerMayReturn {
            await withCheckedContinuation { observerWaiter = $0 }
        }
        history.append(.observerReturned)
    }

    func waitForObserver() async -> ScopedConnectionCloseObservation? {
        if let observation { return observation }
        if scopeFinished { return nil }
        return await withCheckedContinuation { observationWaiter = $0 }
    }

    func resumeObserver() {
        observerMayReturn = true
        observerWaiter?.resume()
        observerWaiter = nil
    }

    func recordScopeFinished() {
        history.append(.scopeFinished)
        scopeFinished = true
        observationWaiter?.resume(returning: observation)
        observationWaiter = nil
    }
}

private func scopedConnectionCloseObservation(
    _ display: isolated WaylandDisplay
) -> ScopedConnectionCloseObservation {
    ScopedConnectionCloseObservation(
        display: display,
        isClosed: display.isClosed,
        onOwnerThread: display.lifetimeAnchor.executor.isOwnerThread,
        wasCancelled: Task.isCancelled
    )
}

private func scopedConnectionIsOnOwnerThread(_ display: isolated WaylandDisplay) -> Bool {
    display.lifetimeAnchor.executor.isOwnerThread
}
