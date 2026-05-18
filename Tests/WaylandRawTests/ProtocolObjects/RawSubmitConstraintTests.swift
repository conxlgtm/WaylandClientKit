import CWaylandProtocols
import Glibc
import Testing
import WaylandTestSupport

@testable import WaylandRaw

@Suite(.serialized)
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
    func syncobjTimelineFileDescriptorCloseAfterReleaseIsHarmless() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        close(descriptors.readEnd)

        var descriptor = try RawDrmSyncobjTimelineFD(adopting: descriptors.writeEnd)
        let released = descriptor.releaseForWaylandRequest()
        descriptor.close()

        #expect(fileDescriptorIsOpen(released))
        close(released)
    }

    @Test
    func syncobjTimelineFileDescriptorDeinitClosesUnreleasedDescriptor() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        close(descriptors.readEnd)
        let ownedDescriptor = descriptors.writeEnd

        do {
            _ = try RawDrmSyncobjTimelineFD(adopting: ownedDescriptor)
        }

        #expect(!fileDescriptorIsOpen(ownedDescriptor))
    }

    @Test
    func importTimelineSuccessTransfersAndClosesLocalDescriptor() async throws {
        try await withSyncobjManagerRecording { manager in
            let descriptors = try RawFileDescriptor.pipeDescriptors()
            close(descriptors.readEnd)
            var descriptor = try RawDrmSyncobjTimelineFD(adopting: descriptors.writeEnd)

            let timeline = try manager.importTimeline(fileDescriptor: &descriptor)
            defer { timeline.destroy() }
            let descriptorIsClosed = descriptor.isClosed

            let record = unsafe swl_test_syncobj_request_record()
            #expect(unsafe record.kind == SWL_TEST_SYNCOBJ_IMPORT_TIMELINE)
            #expect(unsafe record.fd == descriptors.writeEnd)
            #expect(descriptorIsClosed)
            #expect(!fileDescriptorIsOpen(descriptors.writeEnd))
        }
    }

    @Test
    func importTimelineFailureClosesReleasedDescriptor() async throws {
        try await withSyncobjManagerRecording { manager in
            let descriptors = try RawFileDescriptor.pipeDescriptors()
            close(descriptors.readEnd)
            var descriptor = try RawDrmSyncobjTimelineFD(adopting: descriptors.writeEnd)

            swl_test_syncobj_import_timeline_set_failure(1)

            #expect(throws: RuntimeError.bindFailed("wp_linux_drm_syncobj_timeline_v1")) {
                _ = try manager.importTimeline(fileDescriptor: &descriptor)
            }
            let descriptorIsClosed = descriptor.isClosed
            let record = unsafe swl_test_syncobj_request_record()
            #expect(unsafe record.kind == SWL_TEST_SYNCOBJ_IMPORT_TIMELINE)
            #expect(descriptorIsClosed)
            #expect(!fileDescriptorIsOpen(descriptors.writeEnd))
        }
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

private func withSyncobjManagerRecording(
    _ body: (RawLinuxDrmSyncobjManager) throws -> Void
) async throws {
    try await CoreRequestRecordingGate.withExclusiveRecording {
        swl_test_core_request_recording_begin()
        defer { swl_test_core_request_recording_end() }

        try await SyncobjRequestRecordingGate.withExclusiveRecording {
            swl_test_syncobj_request_recording_begin()
            defer { swl_test_syncobj_request_recording_end() }

            let manager = try RawLinuxDrmSyncobjManager(
                pointer: try unsafe #require(OpaquePointer(bitPattern: 0xD101)),
                version: 1,
                proxyAdoption: RawProxyAdoptionContext(
                    eventQueue: RawEventQueue.testingQueueWithoutDestroy(
                        opaquePointer: try unsafe #require(
                            OpaquePointer(bitPattern: 0xD102)
                        )
                    )
                )
            )
            defer { manager.destroy() }

            try body(manager)
        }
    }
}

private func fileDescriptorIsOpen(_ fileDescriptor: Int32) -> Bool {
    fcntl(fileDescriptor, F_GETFD) != -1
}
