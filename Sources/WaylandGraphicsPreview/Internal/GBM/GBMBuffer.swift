import CGBMShims
import WaylandRaw

package struct GBMDmabufPlaneLayout: Equatable, Sendable {
    package let index: Int
    package let offset: UInt32
    package let stride: UInt32
}

package struct GBMDmabufPlaneExport: ~Copyable {
    package let layout: GBMDmabufPlaneLayout
    package var descriptor: RawLinuxDmabufPlaneFileDescriptor
}

@safe
package final class GBMDmabufExport {
    private var rawExport: swl_gbm_bo_export

    package let width: UInt32
    package let height: UInt32
    package let format: UInt32
    package let modifier: UInt64
    package let planeCount: Int

    package init(adopting exportedBuffer: swl_gbm_bo_export) {
        rawExport = exportedBuffer
        width = exportedBuffer.width
        height = exportedBuffer.height
        format = exportedBuffer.format
        modifier = exportedBuffer.modifier
        planeCount = Int(exportedBuffer.plane_count)
    }

    package static func exportingBuffer(
        _ bufferPointer: OpaquePointer
    ) throws(GBMAllocationError) -> GBMDmabufExport {
        var exportedBuffer = swl_gbm_bo_export()
        guard unsafe swl_gbm_bo_export_dmabuf(bufferPointer, &exportedBuffer) == 0 else {
            throw GBMAllocationError.exportFailed(
                errno: GBMAllocationError.capturedCurrentErrno()
            )
        }

        return GBMDmabufExport(adopting: exportedBuffer)
    }

    package var planeIndices: Range<Int> {
        0..<planeCount
    }

    package func planeLayout(
        at index: Int
    ) throws(GBMAllocationError) -> GBMDmabufPlaneLayout {
        guard index >= 0, index < planeCount else {
            throw GBMAllocationError.invalidPlaneIndex(index)
        }

        let planeIndex = UInt32(index)
        return GBMDmabufPlaneLayout(
            index: index,
            offset: unsafe swl_gbm_bo_export_plane_offset(&rawExport, planeIndex),
            stride: unsafe swl_gbm_bo_export_plane_stride(&rawExport, planeIndex)
        )
    }

    package func takePlaneFileDescriptor(
        at index: Int
    ) throws(GBMAllocationError) -> RawLinuxDmabufPlaneFileDescriptor {
        guard index >= 0, index < planeCount else {
            throw GBMAllocationError.invalidPlaneIndex(index)
        }

        let fd = unsafe swl_gbm_bo_export_take_plane_fd(&rawExport, UInt32(index))
        guard fd >= 0 else {
            throw GBMAllocationError.planeFileDescriptorAlreadyTaken(index)
        }

        do {
            return try RawLinuxDmabufPlaneFileDescriptor(adopting: fd)
        } catch {
            throw GBMAllocationError.planeFileDescriptorAlreadyTaken(index)
        }
    }

    package func takePlaneExport(
        at index: Int
    ) throws(GBMAllocationError) -> GBMDmabufPlaneExport {
        let layout = try planeLayout(at: index)
        let descriptor = try takePlaneFileDescriptor(at: index)

        return GBMDmabufPlaneExport(layout: layout, descriptor: descriptor)
    }

    deinit {
        unsafe swl_gbm_bo_export_close(&rawExport)
    }
}

@safe
package final class GBMBuffer {
    private var pointer: OpaquePointer?
    private let device: GBMDevice

    @safe
    package init(pointer bufferPointer: OpaquePointer, device bufferDevice: GBMDevice) {
        unsafe pointer = bufferPointer
        device = bufferDevice
    }

    @safe
    package func withLiveBufferPointer<Result>(
        _ body: (OpaquePointer) throws(GBMAllocationError) -> Result
    ) throws(GBMAllocationError) -> Result {
        guard let bufferPointer = unsafe pointer else {
            throw GBMAllocationError.bufferDestroyed
        }

        return unsafe try body(bufferPointer)
    }

    @safe
    package func exportDmabuf() throws(GBMAllocationError) -> GBMDmabufExport {
        try withLiveBufferPointer { bufferPointer throws(GBMAllocationError) in
            unsafe try GBMDmabufExport.exportingBuffer(bufferPointer)
        }
    }

    package func destroy() {
        guard let bufferPointer = unsafe pointer else { return }

        unsafe self.pointer = nil
        unsafe swl_gbm_bo_destroy(bufferPointer)
    }

    deinit {
        destroy()
    }
}
