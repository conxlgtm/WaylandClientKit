import CGBMShims
import Glibc
import Testing

@testable import WaylandGraphicsCore
@testable import WaylandRaw

@Suite
struct GBMDeviceTests {
    @Test
    func constantsMirrorShimValues() {
        #expect(GBMDRMFormat.xrgb8888 == swl_drm_format_xrgb8888())
        #expect(GBMDRMFormat.argb8888 == swl_drm_format_argb8888())
        #expect(GBMDRMModifier.linear == swl_drm_format_mod_linear())
        #expect(GBMDRMModifier.invalid == swl_drm_format_mod_invalid())
        #expect(GBMBufferUseFlags.windowRendering == [.rendering])
    }

    @Test
    func bufferSizeRejectsZeroDimensions() {
        #expect(
            throws: GBMAllocationError.invalidBufferDimensions(width: 0, height: 1)
        ) {
            _ = try GBMBufferSize(width: 0, height: 1)
        }
        #expect(
            throws: GBMAllocationError.invalidBufferDimensions(width: 1, height: 0)
        ) {
            _ = try GBMBufferSize(width: 1, height: 0)
        }
    }

    @Test
    func allocationDescriptorCapturesDmabufSelection() throws {
        let size = try GBMBufferSize(width: 640, height: 480)
        let formatModifier = RawLinuxDmabufFormatModifier(
            format: GBMDRMFormat.xrgb8888,
            modifier: GBMDRMModifier.linear
        )

        let descriptor = GBMBufferAllocationDescriptor(
            size: size,
            formatModifier: formatModifier,
            flags: [.rendering, .linear]
        )

        #expect(descriptor.size == size)
        #expect(descriptor.format == GBMDRMFormat.xrgb8888)
        #expect(descriptor.modifier == GBMDRMModifier.linear)
        #expect(descriptor.flags == [.rendering, .linear])
    }

    @Test
    func renderNodeFileDescriptorRejectsNegativeDescriptor() {
        #expect(throws: GBMAllocationError.invalidRenderNodeFileDescriptor(-1)) {
            _ = try GBMRenderNodeFileDescriptor(adopting: -1)
        }
    }

    @Test
    func allocationErrorCapturesCurrentErrnoOrFallback() {
        errno = ENODEV
        #expect(GBMAllocationError.capturedCurrentErrno() == ENODEV)

        errno = 0
        #expect(GBMAllocationError.capturedCurrentErrno() == EIO)
    }

    @Test
    func destroyClosesAdoptedRenderNodeDescriptor() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.readEnd)
        }
        try makeNonBlocking(descriptors.readEnd)
        let renderNode = try GBMRenderNodeFileDescriptor(adopting: descriptors.writeEnd)
        let device = GBMDevice(testingAdoptingRenderNodeFileDescriptor: renderNode)

        device.destroy()

        var byte = UInt8(0)
        let readByteCount = unsafe withUnsafeMutableBytes(of: &byte) { buffer in
            unsafe Glibc.read(descriptors.readEnd, buffer.baseAddress, 1)
        }
        #expect(readByteCount == 0)
    }
}

private func makeNonBlocking(_ fileDescriptor: Int32) throws {
    let flags = Glibc.fcntl(fileDescriptor, F_GETFL)
    #expect(flags >= 0)
    try #require(flags >= 0)

    let result = Glibc.fcntl(fileDescriptor, F_SETFL, flags | O_NONBLOCK)
    #expect(result == 0)
}
