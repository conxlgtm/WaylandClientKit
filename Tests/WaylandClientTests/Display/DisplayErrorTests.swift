import Glibc
import Testing
import WaylandRaw
import WaylandRuntime

@testable import WaylandClient

@Suite
struct WaylandDisplayErrorMappingTests {
    @Test
    func displayEventSourceMapsExecutorPollFailedToSystemError() {
        let systemError = RawSystemError(
            uncheckedErrno: EIO,
            operation: .pollEventLoop
        )
        let clientSystemError = WaylandSystemError(systemError)
        let error = WaylandDisplayError(
            WaylandThreadExecutorError.eventLoop(.system(systemError))
        )

        #expect(error == .systemError(clientSystemError))
    }

    @Test
    func displayEventSourceMapsExecutorPollEventFailureToEventLoopError() {
        let revents = Int16(POLLHUP)
        let error = WaylandDisplayError(
            WaylandThreadExecutorError.eventLoop(
                .unexpectedDisplayRevents(revents: revents)
            )
        )

        #expect(error == .eventLoopError(.unexpectedDisplayRevents(revents: revents)))
    }

    @Test
    func runtimeEventLoopSystemErrorMapsToDisplaySystemError() {
        let systemError = RawSystemError(
            uncheckedErrno: EIO,
            operation: .displayReadEvents
        )
        let clientSystemError = WaylandSystemError(systemError)
        let error = WaylandDisplayError(RuntimeError.eventLoop(.system(systemError)))

        #expect(error == .systemError(clientSystemError))
    }

    @Test
    func waylandSystemErrnoRejectsZero() {
        #expect(throws: WaylandSystemErrorConstructionError.nonPositiveErrno(0)) {
            _ = try WaylandSystemErrno(0)
        }
    }

    @Test
    func waylandSystemErrnoRejectsNegativeValue() {
        #expect(throws: WaylandSystemErrorConstructionError.nonPositiveErrno(-1)) {
            _ = try WaylandSystemErrno(-1)
        }
    }

    @Test
    func runtimeZeroErrnoMapsToInvariantFailure() {
        let runtimeError = RuntimeError.systemError(errno: 0, operation: .displayReadEvents)
        let error = WaylandDisplayError(runtimeError)

        #expect(
            error == .internalInvariantViolation(.message(runtimeError.description))
        )
    }
}
