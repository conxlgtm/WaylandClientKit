import CDRMSystem
import Glibc
import WaylandRaw

package final class DRMSyncobjTimeline {
    private let deviceFileDescriptor: Int32
    private var handle: UInt32?

    package init(deviceFileDescriptor drmFileDescriptor: Int32) throws(GBMAllocationError) {
        deviceFileDescriptor = drmFileDescriptor

        var timelineHandle: UInt32 = 0
        guard unsafe drmSyncobjCreate(drmFileDescriptor, 0, &timelineHandle) == 0 else {
            throw GBMAllocationError.syncobjCreationFailed(
                errno: GBMAllocationError.capturedCurrentErrno()
            )
        }

        handle = timelineHandle
    }

    package func exportFileDescriptor() throws(GBMAllocationError) -> RawDrmSyncobjTimelineFD {
        guard let handle else {
            throw GBMAllocationError.deviceDestroyed
        }

        var fileDescriptor: Int32 = -1
        guard unsafe drmSyncobjHandleToFD(deviceFileDescriptor, handle, &fileDescriptor) == 0 else {
            throw GBMAllocationError.syncobjFileDescriptorExportFailed(
                errno: GBMAllocationError.capturedCurrentErrno()
            )
        }

        do {
            return try RawDrmSyncobjTimelineFD(adopting: fileDescriptor)
        } catch {
            Glibc.close(fileDescriptor)
            throw GBMAllocationError.syncobjFileDescriptorExportFailed(
                errno: GBMAllocationError.capturedCurrentErrno()
            )
        }
    }

    package func signal(_ point: RawSyncobjTimelinePoint) throws(GBMAllocationError) {
        guard let handle else {
            throw GBMAllocationError.deviceDestroyed
        }

        var timelineHandle = handle
        var timelinePoint = point.rawValue
        guard
            unsafe drmSyncobjTimelineSignal(
                deviceFileDescriptor,
                &timelineHandle,
                &timelinePoint,
                1
            ) == 0
        else {
            throw GBMAllocationError.syncobjTimelineSignalFailed(
                point: point.rawValue,
                errno: GBMAllocationError.capturedCurrentErrno()
            )
        }
    }

    package func wait(
        _ point: RawSyncobjTimelinePoint,
        timeoutNanoseconds: Int64,
        waitForSubmit: Bool = false
    ) throws(GBMAllocationError) {
        guard let handle else {
            throw GBMAllocationError.deviceDestroyed
        }

        let deadlineNanoseconds = try Self.monotonicDeadlineNanoseconds(
            after: timeoutNanoseconds,
            point: point
        )
        var timelineHandle = handle
        var timelinePoint = point.rawValue
        var firstSignaled: UInt32 = 0
        let flags = waitForSubmit ? Self.waitForSubmitFlag : 0
        let waitResult = Self.retryingInterruptedWait {
            unsafe drmSyncobjTimelineWait(
                deviceFileDescriptor,
                &timelineHandle,
                &timelinePoint,
                1,
                deadlineNanoseconds,
                flags,
                &firstSignaled
            )
        }
        guard waitResult == 0 else {
            throw GBMAllocationError.syncobjTimelineWaitFailed(
                point: point.rawValue,
                errno: GBMAllocationError.capturedCurrentErrno()
            )
        }
    }

    package static let waitForSubmitFlag = UInt32(DRM_SYNCOBJ_WAIT_FLAGS_WAIT_FOR_SUBMIT)

    package static func retryingInterruptedWait(
        _ wait: () -> Int32
    ) -> Int32 {
        while true {
            let result = wait()
            guard result < 0, errno == EINTR else {
                return result
            }
        }
    }

    package static func absoluteDeadlineNanoseconds(
        currentSeconds: Int64,
        currentNanoseconds: Int64,
        timeoutNanoseconds: Int64
    ) -> Int64 {
        let (secondsNanoseconds, secondsOverflow) =
            currentSeconds.multipliedReportingOverflow(by: 1_000_000_000)
        guard !secondsOverflow else {
            return currentSeconds >= 0 ? Int64.max : Int64.min
        }

        let (currentTimeNanoseconds, currentOverflow) =
            secondsNanoseconds.addingReportingOverflow(currentNanoseconds)
        guard !currentOverflow else {
            return currentNanoseconds >= 0 ? Int64.max : Int64.min
        }

        let (deadlineNanoseconds, deadlineOverflow) =
            currentTimeNanoseconds.addingReportingOverflow(timeoutNanoseconds)
        guard !deadlineOverflow else {
            return timeoutNanoseconds >= 0 ? Int64.max : Int64.min
        }

        return deadlineNanoseconds
    }

    private static func monotonicDeadlineNanoseconds(
        after timeoutNanoseconds: Int64,
        point: RawSyncobjTimelinePoint
    ) throws(GBMAllocationError) -> Int64 {
        var timestamp = timespec()
        guard unsafe clock_gettime(CLOCK_MONOTONIC, &timestamp) == 0 else {
            throw GBMAllocationError.syncobjTimelineWaitFailed(
                point: point.rawValue,
                errno: GBMAllocationError.capturedCurrentErrno()
            )
        }

        return absoluteDeadlineNanoseconds(
            currentSeconds: Int64(timestamp.tv_sec),
            currentNanoseconds: Int64(timestamp.tv_nsec),
            timeoutNanoseconds: timeoutNanoseconds
        )
    }

    package func destroy() {
        guard let timelineHandle = handle else { return }

        handle = nil
        _ = drmSyncobjDestroy(deviceFileDescriptor, timelineHandle)
    }

    deinit {
        destroy()
    }
}
