import Testing

@testable import WaylandGraphicsCore

@Suite
struct DRMSyncobjTimelineTests {
    @Test
    func waitForSubmitFlagMatchesDRMSubmitWaitFlag() {
        #expect(DRMSyncobjTimeline.waitForSubmitFlag == UInt32(1 << 1))
    }

    @Test
    func absoluteDeadlineAddsTimeoutToMonotonicTime() {
        let deadline = DRMSyncobjTimeline.absoluteDeadlineNanoseconds(
            currentSeconds: 2,
            currentNanoseconds: 900_000_000,
            timeoutNanoseconds: 250_000_000
        )

        #expect(deadline == 3_150_000_000)
    }

    @Test
    func absoluteDeadlineClampsPositiveOverflow() {
        let deadline = DRMSyncobjTimeline.absoluteDeadlineNanoseconds(
            currentSeconds: Int64.max / 1_000_000_000,
            currentNanoseconds: 999_999_999,
            timeoutNanoseconds: Int64.max
        )

        #expect(deadline == Int64.max)
    }
}
