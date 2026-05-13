import CGBMShims
import Testing

@testable import WaylandGraphicsPreview
@testable import WaylandRaw

@Suite
struct DRMRenderNodeSelectionTests {
    @Test
    func expectedDeviceIDByteCountComesFromDRMShim() {
        #expect(DRMRenderNodeSelector.expectedDeviceIDByteCount > 0)
        #expect(
            DRMRenderNodeSelector.expectedDeviceIDByteCount
                == Int(swl_drm_device_id_byte_count())
        )
    }

    @Test
    func invalidDeviceIDByteCountIsRejectedBeforeDRMLookup() {
        let device = RawLinuxDmabufDevice(bytes: [])

        #expect(
            throws: GBMAllocationError.invalidDeviceIDByteCount(
                expected: DRMRenderNodeSelector.expectedDeviceIDByteCount,
                actual: 0
            )
        ) {
            _ = try DRMRenderNodeSelector.renderNodePath(for: device)
        }
    }

    @Test
    func drmShimRejectsShortDeviceIDBytes() {
        var path = [CChar](repeating: 0, count: Int(swl_drm_render_node_path_max()))
        let byteCount = max(Int(swl_drm_device_id_byte_count()) - 1, 0)
        let deviceIDBytes = [UInt8](repeating: 0, count: byteCount)

        let result = unsafe deviceIDBytes.withUnsafeBufferPointer { bytes in
            unsafe path.withUnsafeMutableBufferPointer { pathBytes in
                unsafe swl_drm_render_node_path_from_device_bytes(
                    bytes.baseAddress,
                    UInt32(bytes.count),
                    pathBytes.baseAddress,
                    UInt32(pathBytes.count)
                )
            }
        }

        #expect(result == -1)
    }
}
