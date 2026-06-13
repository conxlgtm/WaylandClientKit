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

    package func destroy() {
        guard let timelineHandle = handle else { return }

        handle = nil
        _ = drmSyncobjDestroy(deviceFileDescriptor, timelineHandle)
    }

    deinit {
        destroy()
    }
}
