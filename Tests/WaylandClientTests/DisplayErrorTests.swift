import Glibc
import Testing
import WaylandRawUnsafeShim

@testable import WaylandClient

@Suite
struct WaylandDisplayErrorMappingTests {
    @Test
    func displayEventSourceMapsExecutorPollFailedToSystemError() {
        let error = WaylandDisplayError(WaylandThreadExecutorError.pollFailed(EIO))

        #expect(error == .systemError(errno: EIO))
    }

    @Test
    func displayEventSourceMapsExecutorPollEventFailureToEventLoopError() {
        let revents = Int16(POLLHUP)
        let error = WaylandDisplayError(
            WaylandThreadExecutorError.pollEventFailed(revents: revents)
        )

        #expect(error == .eventLoopError(.pollEventFailed(revents: revents)))
    }
}
