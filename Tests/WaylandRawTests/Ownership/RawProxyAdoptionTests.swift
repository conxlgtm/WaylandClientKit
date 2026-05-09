import Testing

@testable import WaylandRaw

@Suite
struct RawProxyAdoptionTests {
    final class FailureRecorder: RawInvariantFailureReporter {
        var failures: [RawInvariantFailure] = []

        func reportFatalRawInvariantFailure(_ failure: RawInvariantFailure) {
            failures.append(failure)
        }
    }

    @Test
    func queueMismatchReportsFatalFailureBeforeThrowing() {
        let recorder = FailureRecorder()
        let sink = RawInvariantFailureSink()
        sink.reporter = recorder
        #expect(throws: RuntimeError.proxyQueueMismatch("wl_surface")) {
            try RawEventQueue.reportQueueMismatch(
                interface: "wl_surface",
                invariantFailureSink: sink
            )
        }
        #expect(recorder.failures == [.proxyOnWrongQueue(interface: "wl_surface")])
    }
}
