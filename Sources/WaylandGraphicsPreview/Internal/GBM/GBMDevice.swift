import CGBMShims
import Glibc
import WaylandRaw

package struct GBMRenderNodeFileDescriptor: ~Copyable {
    private var storage: Int32?

    package init(adopting fileDescriptor: Int32) throws(GBMAllocationError) {
        guard fileDescriptor >= 0 else {
            throw GBMAllocationError.invalidRenderNodeFileDescriptor(fileDescriptor)
        }

        storage = fileDescriptor
    }

    package var rawValue: Int32 {
        guard let storage else {
            preconditionFailure("GBM render node file descriptor was already released")
        }

        return storage
    }

    package mutating func releaseForGBMDevice() -> Int32 {
        let fd = rawValue
        storage = nil
        return fd
    }

    package mutating func close() {
        guard let fd = storage else { return }

        storage = nil
        Glibc.close(fd)
    }

    deinit {
        if let storage {
            Glibc.close(storage)
        }
    }
}

package struct GBMBufferSize: Equatable, Sendable {
    package let width: UInt32
    package let height: UInt32

    package init(width bufferWidth: UInt32, height bufferHeight: UInt32)
        throws(GBMAllocationError)
    {
        guard bufferWidth > 0, bufferHeight > 0 else {
            throw GBMAllocationError.invalidBufferDimensions(
                width: bufferWidth,
                height: bufferHeight
            )
        }

        width = bufferWidth
        height = bufferHeight
    }
}

package struct GBMBufferAllocationDescriptor: Equatable, Sendable {
    package let size: GBMBufferSize
    package let format: UInt32
    package let modifier: UInt64
    package let flags: GBMBufferUseFlags

    package init(
        size bufferSize: GBMBufferSize,
        formatModifier selectedFormatModifier: RawLinuxDmabufFormatModifier,
        flags bufferFlags: GBMBufferUseFlags = .windowRendering
    ) {
        size = bufferSize
        format = selectedFormatModifier.format
        modifier = selectedFormatModifier.modifier
        flags = bufferFlags
    }
}

@safe
package final class GBMDevice {
    private var pointer: OpaquePointer?
    private var renderNodeFileDescriptor: Int32?

    @safe
    package init(
        adoptingRenderNodeFileDescriptor renderNode: consuming GBMRenderNodeFileDescriptor
    ) throws(GBMAllocationError) {
        var renderNode = renderNode
        let fd = renderNode.releaseForGBMDevice()
        guard let devicePointer = unsafe swl_gbm_create_device(fd) else {
            let errorNumber = GBMAllocationError.capturedCurrentErrno()
            Glibc.close(fd)
            throw GBMAllocationError.deviceCreationFailed(errno: errorNumber)
        }

        unsafe pointer = devicePointer
        renderNodeFileDescriptor = fd
    }

    package init(
        testingAdoptingRenderNodeFileDescriptor renderNode: consuming GBMRenderNodeFileDescriptor
    ) {
        var renderNode = renderNode
        unsafe pointer = nil
        renderNodeFileDescriptor = renderNode.releaseForGBMDevice()
    }

    @safe package var backendName: String? {
        guard let devicePointer = unsafe pointer else { return nil }
        guard let name = unsafe swl_gbm_device_get_backend_name(devicePointer) else {
            return nil
        }

        return unsafe String(cString: name)
    }

    package var drmFileDescriptor: Int32 {
        get throws(GBMAllocationError) {
            guard let renderNodeFileDescriptor else {
                throw GBMAllocationError.deviceDestroyed
            }

            return renderNodeFileDescriptor
        }
    }

    @safe
    package func withUnsafeDevicePointer<Result>(
        _ body: (OpaquePointer) throws(GBMAllocationError) -> Result
    ) throws(GBMAllocationError) -> Result {
        guard let devicePointer = unsafe pointer else {
            throw GBMAllocationError.deviceDestroyed
        }

        return unsafe try body(devicePointer)
    }

    @safe
    package func isFormatSupported(
        format: UInt32,
        flags: GBMBufferUseFlags
    ) throws(GBMAllocationError) -> Bool {
        try withUnsafeDevicePointer { devicePointer in
            unsafe swl_gbm_device_is_format_supported(
                devicePointer,
                format,
                flags.rawValue
            ) != 0
        }
    }

    @safe
    package func formatModifierPlaneCount(
        format: UInt32,
        modifier: UInt64
    ) throws(GBMAllocationError) -> Int {
        try withUnsafeDevicePointer { devicePointer throws(GBMAllocationError) in
            let planeCount = unsafe swl_gbm_device_get_format_modifier_plane_count(
                devicePointer,
                format,
                modifier
            )
            guard planeCount >= 0 else {
                throw GBMAllocationError.exportFailed(
                    errno: GBMAllocationError.capturedCurrentErrno()
                )
            }

            return Int(planeCount)
        }
    }

    @safe
    package func allocateBuffer(
        _ descriptor: GBMBufferAllocationDescriptor
    ) throws(GBMAllocationError) -> GBMBuffer {
        let bufferPointer = try withUnsafeDevicePointer { devicePointer in
            unsafe swl_gbm_bo_create_for_modifier(
                devicePointer,
                descriptor.size.width,
                descriptor.size.height,
                descriptor.format,
                descriptor.modifier,
                descriptor.flags.rawValue
            )
        }
        guard let bufferPointer = unsafe bufferPointer else {
            throw GBMAllocationError.bufferAllocationFailed(
                format: descriptor.format,
                modifier: descriptor.modifier,
                flags: descriptor.flags.rawValue,
                errno: GBMAllocationError.capturedCurrentErrno()
            )
        }

        return GBMBuffer(pointer: bufferPointer, device: self)
    }

    package func destroy() {
        let devicePointer = unsafe pointer
        let renderNodeFD = renderNodeFileDescriptor

        unsafe self.pointer = nil
        renderNodeFileDescriptor = nil

        if let devicePointer = unsafe devicePointer {
            unsafe swl_gbm_device_destroy(devicePointer)
        }
        if let renderNodeFD {
            Glibc.close(renderNodeFD)
        }
    }

    deinit {
        destroy()
    }
}
