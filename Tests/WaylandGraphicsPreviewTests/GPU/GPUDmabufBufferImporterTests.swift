import CGBMShims
import Glibc
import Testing

@testable import WaylandGraphicsPreview
@testable import WaylandRaw

@Suite
struct GPUDmabufBufferImporterTests {
    @Test
    func importDescriptorCapturesExportShape() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.readEnd)
        }
        let export = GBMDmabufExport(
            adopting: rawExport(fileDescriptor: descriptors.writeEnd)
        )

        let descriptor = try GPUDmabufBufferImport.importDescriptor(for: export)

        #expect(
            descriptor
                == GPUDmabufBufferImportDescriptor(
                    width: 64,
                    height: 32,
                    format: swl_drm_format_xrgb8888(),
                    modifier: swl_drm_format_mod_linear(),
                    planeCount: 1
                )
        )
        #expect(Array(descriptor.planeIndices) == [0])
    }

    @Test
    func importDescriptorRejectsEmptyPlaneSet() {
        let export = GBMDmabufExport(adopting: rawExport(planeCount: 0))

        #expect(throws: GPUDmabufBufferImportError.emptyPlaneSet) {
            _ = try GPUDmabufBufferImport.importDescriptor(for: export)
        }
    }

    @Test
    func importDescriptorRejectsOversizedDimensions() {
        let export = GBMDmabufExport(
            adopting: rawExport(width: UInt32(Int32.max) + 1)
        )

        #expect(
            throws: GPUDmabufBufferImportError.dimensionsExceedInt32(
                width: UInt32(Int32.max) + 1,
                height: 32
            )
        ) {
            _ = try GPUDmabufBufferImport.importDescriptor(for: export)
        }
    }

    @Test
    func terminalEventAfterCreatedReportsFailure() {
        var failures: [GPUDmabufBufferImportError] = []
        let importRequest = GPUDmabufBufferImport(
            testingInitialState: .created
        ) { _ in
            Issue.record("terminal-state test should not create a buffer")
        } onFailure: { error in
            failures.append(error)
        }

        importRequest.testingHandle(.failed)

        #expect(failures == [.useAfterTerminalState(.created)])
        #expect(importRequest.state == .created)
    }

    @Test
    func terminalEventAfterFailedReportsFailure() {
        var failures: [GPUDmabufBufferImportError] = []
        let importRequest = GPUDmabufBufferImport(
            testingInitialState: .failed
        ) { _ in
            Issue.record("terminal-state test should not create a buffer")
        } onFailure: { error in
            failures.append(error)
        }

        importRequest.testingHandle(.failed)

        #expect(failures == [.useAfterTerminalState(.failed)])
        #expect(importRequest.state == .failed)
    }

    @Test
    func importStateClassifiesEventAcceptanceAndTerminalStates() {
        #expect(GPUDmabufBufferImportState.createRequested.acceptsCompositorEvent)
        #expect(!GPUDmabufBufferImportState.createRequested.isTerminal)
        #expect(!GPUDmabufBufferImportState.createRequested.isDestroyed)

        #expect(!GPUDmabufBufferImportState.created.acceptsCompositorEvent)
        #expect(GPUDmabufBufferImportState.created.isTerminal)

        #expect(!GPUDmabufBufferImportState.failed.acceptsCompositorEvent)
        #expect(GPUDmabufBufferImportState.failed.isTerminal)

        #expect(!GPUDmabufBufferImportState.destroyed.acceptsCompositorEvent)
        #expect(GPUDmabufBufferImportState.destroyed.isTerminal)
        #expect(GPUDmabufBufferImportState.destroyed.isDestroyed)
    }
}

private func rawExport(
    fileDescriptor: Int32 = -1,
    width: UInt32 = 64,
    height: UInt32 = 32,
    planeCount: UInt32 = 1
) -> swl_gbm_bo_export {
    var exportedBuffer = swl_gbm_bo_export()
    exportedBuffer.width = width
    exportedBuffer.height = height
    exportedBuffer.format = swl_drm_format_xrgb8888()
    exportedBuffer.modifier = swl_drm_format_mod_linear()
    exportedBuffer.plane_count = planeCount
    exportedBuffer.planes.0 = swl_gbm_bo_plane(
        fd: fileDescriptor,
        offset: 0,
        stride: 256
    )
    return exportedBuffer
}
