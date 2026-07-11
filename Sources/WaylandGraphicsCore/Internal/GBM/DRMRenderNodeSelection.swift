import CGBMShims
import Glibc
import WaylandRaw

package enum DRMRenderNodeSelector {
    package static var expectedDeviceIDByteCount: Int {
        Int(swl_drm_device_id_byte_count())
    }

    package static func renderNodePath(
        for device: RawLinuxDmabufDevice
    ) throws(GBMAllocationError) -> String {
        let expectedByteCount = expectedDeviceIDByteCount
        guard device.bytes.count == expectedByteCount else {
            throw GBMAllocationError.invalidDeviceIDByteCount(
                expected: expectedByteCount,
                actual: device.bytes.count
            )
        }

        var pathBytes = [CChar](
            repeating: 0,
            count: Int(swl_drm_render_node_path_max())
        )
        let result = unsafe device.bytes.withUnsafeBufferPointer { deviceIDBytes in
            unsafe pathBytes.withUnsafeMutableBufferPointer { outputPathBytes in
                unsafe swl_drm_render_node_path_from_device_bytes(
                    deviceIDBytes.baseAddress,
                    UInt32(deviceIDBytes.count),
                    outputPathBytes.baseAddress,
                    UInt32(outputPathBytes.count)
                )
            }
        }
        guard result == 0 else {
            throw GBMAllocationError.renderNodeLookupFailed(
                errno: GBMAllocationError.capturedCurrentErrno()
            )
        }

        let path = unsafe pathBytes.withUnsafeBufferPointer { pathBuffer -> String? in
            guard let baseAddress = pathBuffer.baseAddress else { return nil }

            return unsafe String(cString: baseAddress)
        }
        guard let path else {
            throw GBMAllocationError.renderNodeLookupFailed(errno: EINVAL)
        }

        return path
    }

    package static func openRenderNode(
        for device: RawLinuxDmabufDevice
    ) throws(GBMAllocationError) -> GBMRenderNodeFileDescriptor {
        let path = try renderNodePath(for: device)
        let fd = unsafe path.withCString { pathPointer in
            unsafe Glibc.open(pathPointer, O_RDWR | O_CLOEXEC)
        }
        guard fd >= 0 else {
            throw GBMAllocationError.openRenderNodeFailed(
                path: path,
                errno: GBMAllocationError.capturedCurrentErrno()
            )
        }

        return try GBMRenderNodeFileDescriptor(adopting: fd)
    }
}
