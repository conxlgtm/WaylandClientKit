import CGBMShims
import Glibc
import Testing

@testable import WaylandGraphicsCore
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
        var export = GBMDmabufExport(
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
    func takingPlaneExportTransfersLayoutAndDescriptor() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.readEnd)
        }
        var export = GBMDmabufExport(
            adopting: rawExport(
                fileDescriptor: descriptors.writeEnd,
                offset: 32,
                stride: 128
            )
        )
        #expect(Array(export.planeIndices) == [0])

        var plane = try export.takePlaneExport(at: 0)
        defer {
            plane.descriptor.close()
        }

        #expect(plane.layout == GBMDmabufPlaneLayout(index: 0, offset: 32, stride: 128))
        #expect(plane.descriptor.rawValue == descriptors.writeEnd)
        #expect(Glibc.fcntl(plane.descriptor.rawValue, F_GETFD) != -1)
    }

    @Test
    func exportCloseDoesNotCloseTakenPlaneDescriptor() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.readEnd)
        }
        var export = GBMDmabufExport(
            adopting: rawExport(fileDescriptor: descriptors.writeEnd)
        )
        var planeDescriptor = try export.takePlaneFileDescriptor(at: 0)
        defer {
            planeDescriptor.close()
        }

        _ = consume export

        #expect(Glibc.fcntl(planeDescriptor.rawValue, F_GETFD) != -1)
    }

    @Test
    func exportCloseClosesUntakenPlaneDescriptor() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.readEnd)
        }
        try makeNonBlocking(descriptors.readEnd)
        let export = GBMDmabufExport(
            adopting: rawExport(fileDescriptor: descriptors.writeEnd)
        )
        #expect(export.planeCount == 1)
        _ = consume export

        var byte = UInt8(0)
        let readByteCount = withUnsafeMutableBytes(of: &byte) { buffer in
            unsafe Glibc.read(descriptors.readEnd, buffer.baseAddress, 1)
        }
        #expect(readByteCount == 0)
    }

    @Test
    func secondTakeForSamePlaneFails() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.readEnd)
        }
        var export = GBMDmabufExport(
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

    @Test(arguments: 1...4)
    func movedExportClosesEveryUntakenPlaneAfterPartialTransfer(planeCount: Int) async throws {
        for takenCount in 0...planeCount {
            let pipes = try (0..<planeCount).map { _ in try RawFileDescriptor.pipeDescriptors() }
            defer {
                for pipe in pipes {
                    Glibc.close(pipe.readEnd)
                }
            }
            var raw = rawExport(fileDescriptor: pipes[0].writeEnd)
            raw.plane_count = UInt32(planeCount)
            for index in 0..<planeCount {
                let plane = swl_gbm_bo_plane(
                    fd: pipes[index].writeEnd, offset: UInt32(index * 16), stride: 256
                )
                switch index {
                case 0: raw.planes.0 = plane
                case 1: raw.planes.1 = plane
                case 2: raw.planes.2 = plane
                default: raw.planes.3 = plane
                }
                try makeNonBlocking(pipes[index].readEnd)
            }
            let owner = GBMExportTransferOwner()
            var export = await owner.transfer(GBMDmabufExport(adopting: raw))
            for index in 0..<takenCount {
                var plane = try export.takePlaneExport(at: index)
                #expect(plane.layout.offset == UInt32(index * 16))
                #expect(plane.layout.stride == 256)
                #expect(plane.descriptor.rawValue == pipes[index].writeEnd)
                plane.descriptor.close()
            }
            for index in takenCount..<planeCount {
                var byte: UInt8 = 0
                let count = unsafe Glibc.read(pipes[index].readEnd, &byte, 1)
                #expect(count == -1)
                #expect(errno == EAGAIN)
            }
            _ = consume export
            for pipe in pipes {
                var byte: UInt8 = 0
                let count = unsafe Glibc.read(pipe.readEnd, &byte, 1)
                #expect(count == 0)
            }
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

private func makeNonBlocking(_ fileDescriptor: Int32) throws {
    let flags = Glibc.fcntl(fileDescriptor, F_GETFL)
    #expect(flags >= 0)
    try #require(flags >= 0)

    let result = Glibc.fcntl(fileDescriptor, F_SETFL, flags | O_NONBLOCK)
    #expect(result == 0)
}

private actor GBMExportTransferOwner {
    func transfer(_ export: consuming GBMDmabufExport) -> GBMDmabufExport {
        export
    }
}
