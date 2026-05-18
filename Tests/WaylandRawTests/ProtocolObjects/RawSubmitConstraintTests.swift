import Glibc
import Testing
@testable import WaylandRaw

struct RawSubmitConstraintTests {
    @Test
    func syncobjTimelinePointSplitsIntoProtocolWords() {
        let point = RawSyncobjTimelinePoint(0x1122_3344_5566_7788)

        #expect(point.highBits == 0x1122_3344)
        #expect(point.lowBits == 0x5566_7788)
    }

    @Test
    func syncobjTimelineFileDescriptorRejectsInvalidDescriptor() {
        #expect(throws: RuntimeError.invalidArgument("drm syncobj timeline fd")) {
            _ = try RawDrmSyncobjTimelineFD(adopting: -1)
        }
    }

    @Test
    func syncobjTimelineFileDescriptorTransfersOnce() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        close(descriptors.readEnd)

        var descriptor = try RawDrmSyncobjTimelineFD(adopting: descriptors.writeEnd)
        let released = descriptor.releaseForWaylandRequest()
        let descriptorIsClosed = descriptor.isClosed

        #expect(released == descriptors.writeEnd)
        #expect(descriptorIsClosed)
        close(released)
    }

    @Test
    func commitTargetTimeRejectsInvalidNanoseconds() {
        #expect(throws: RawCommitTimingError.invalidTimestamp) {
            _ = try RawCommitTargetTime(seconds: 1, nanoseconds: 1_000_000_000)
        }
    }

    @Test
    func commitTargetTimeSplitsSecondsIntoProtocolWords() throws {
        let target = try RawCommitTargetTime(
            seconds: 0x1122_3344_5566_7788,
            nanoseconds: 999_999_999
        )

        #expect(target.secondsHighBits == 0x1122_3344)
        #expect(target.secondsLowBits == 0x5566_7788)
        #expect(target.nanoseconds == 999_999_999)
    }
}
