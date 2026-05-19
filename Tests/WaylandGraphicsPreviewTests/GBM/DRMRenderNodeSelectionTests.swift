import CGBMShims
import Testing

@testable import WaylandGraphicsCore
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

    @Test
    func drmShimPrefersRenderNodeOverPrimaryNode() throws {
        let path = try selectedNodePath(
            availableNodes: swl_drm_node_primary_bit() | swl_drm_node_render_bit(),
            primaryNodePath: "/dev/dri/card0",
            renderNodePath: "/dev/dri/renderD128"
        )

        #expect(path == "/dev/dri/renderD128")
    }

    @Test
    func drmShimRejectsPrimaryNodeWhenRenderNodeIsAbsent() {
        let result = nodePathSelectionResult(
            availableNodes: swl_drm_node_primary_bit(),
            primaryNodePath: "/dev/dri/card0",
            renderNodePath: nil
        )

        #expect(result == -1)
    }
}

private func selectedNodePath(
    availableNodes: UInt32,
    primaryNodePath: String?,
    renderNodePath: String?
) throws -> String {
    var path = [CChar](repeating: 0, count: Int(swl_drm_render_node_path_max()))
    let result = unsafe withOptionalCString(primaryNodePath) { primaryPathPointer in
        unsafe withOptionalCString(renderNodePath) { renderPathPointer in
            unsafe path.withUnsafeMutableBufferPointer { pathBytes in
                unsafe swl_drm_node_path_from_available_nodes(
                    availableNodes,
                    primaryPathPointer,
                    renderPathPointer,
                    pathBytes.baseAddress,
                    UInt32(pathBytes.count)
                )
            }
        }
    }
    #expect(result == 0)
    try #require(result == 0)

    let selectedPath = unsafe path.withUnsafeBufferPointer { pathBytes -> String? in
        guard let baseAddress = pathBytes.baseAddress else { return nil }

        return unsafe String(cString: baseAddress)
    }
    return try #require(selectedPath)
}

private func nodePathSelectionResult(
    availableNodes: UInt32,
    primaryNodePath: String?,
    renderNodePath: String?
) -> Int32 {
    var path = [CChar](repeating: 0, count: Int(swl_drm_render_node_path_max()))
    return unsafe withOptionalCString(primaryNodePath) { primaryPathPointer in
        unsafe withOptionalCString(renderNodePath) { renderPathPointer in
            unsafe path.withUnsafeMutableBufferPointer { pathBytes in
                unsafe swl_drm_node_path_from_available_nodes(
                    availableNodes,
                    primaryPathPointer,
                    renderPathPointer,
                    pathBytes.baseAddress,
                    UInt32(pathBytes.count)
                )
            }
        }
    }
}

private func withOptionalCString<Result>(
    _ string: String?,
    _ body: (UnsafePointer<CChar>?) -> Result
) -> Result {
    guard let string else {
        return body(nil)
    }

    return unsafe string.withCString { pointer in
        unsafe body(pointer)
    }
}
