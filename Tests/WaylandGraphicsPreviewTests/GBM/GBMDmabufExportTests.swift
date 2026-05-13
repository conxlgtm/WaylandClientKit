import CGBMShims
import Glibc
import Testing

@testable import WaylandGraphicsPreview
@testable import WaylandRaw

@Suite(.serialized)
struct GBMDmabufExportTests {
    @Test
    func exportPlaneLayoutDoesNotExposeRawFileDescriptor() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.readEnd)
        }
        let export = GBMDmabufExport(
            adopting: rawExport(
                fileDescriptor: descriptors.writeEnd,
                offset: 16,
                stride: 64
            )
        )

        let layout = try export.planeLayout(at: 0)

        #expect(layout == GBMDmabufPlaneLayout(index: 0, offset: 16, stride: 64))
    }

    @Test
    func takingPlaneDescriptorTransfersOwnership() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.readEnd)
        }
        let export = GBMDmabufExport(
            adopting: rawExport(fileDescriptor: descriptors.writeEnd)
        )
        var planeDescriptor = try export.takePlaneFileDescriptor(at: 0)
        defer {
            planeDescriptor.close()
        }

        #expect(planeDescriptor.rawValue == descriptors.writeEnd)
        #expect(Glibc.fcntl(planeDescriptor.rawValue, F_GETFD) != -1)
    }

    @Test
    func exportCloseDoesNotCloseTakenPlaneDescriptor() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.readEnd)
        }
        var export: GBMDmabufExport? = GBMDmabufExport(
            adopting: rawExport(fileDescriptor: descriptors.writeEnd)
        )
        var planeDescriptor = try #require(export).takePlaneFileDescriptor(at: 0)
        defer {
            planeDescriptor.close()
        }

        export = nil

        #expect(Glibc.fcntl(planeDescriptor.rawValue, F_GETFD) != -1)
    }

    @Test
    func exportCloseClosesUntakenPlaneDescriptor() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        Glibc.close(descriptors.readEnd)
        do {
            _ = GBMDmabufExport(adopting: rawExport(fileDescriptor: descriptors.writeEnd))
        }

        #expect(Glibc.fcntl(descriptors.writeEnd, F_GETFD) == -1)
    }

    @Test
    func secondTakeForSamePlaneFails() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.readEnd)
        }
        let export = GBMDmabufExport(
            adopting: rawExport(fileDescriptor: descriptors.writeEnd)
        )
        var planeDescriptor = try export.takePlaneFileDescriptor(at: 0)
        defer {
            planeDescriptor.close()
        }

        #expect(throws: GBMAllocationError.planeFileDescriptorAlreadyTaken(0)) {
            _ = try export.takePlaneFileDescriptor(at: 0)
        }
    }
}

private func rawExport(
    fileDescriptor: Int32,
    offset: UInt32 = 0,
    stride: UInt32 = 256
) -> swl_gbm_bo_export {
    var exportedBuffer = swl_gbm_bo_export()
    exportedBuffer.width = 64
    exportedBuffer.height = 64
    exportedBuffer.format = swl_drm_format_xrgb8888()
    exportedBuffer.modifier = swl_drm_format_mod_linear()
    exportedBuffer.plane_count = 1
    exportedBuffer.planes.0 = swl_gbm_bo_plane(
        fd: fileDescriptor,
        offset: offset,
        stride: stride
    )
    return exportedBuffer
}
