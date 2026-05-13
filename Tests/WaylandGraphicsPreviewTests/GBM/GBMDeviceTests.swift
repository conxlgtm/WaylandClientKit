import CGBMShims
import Testing

@testable import WaylandGraphicsPreview
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
}
