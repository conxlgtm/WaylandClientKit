import Testing

@testable import WaylandGraphicsPreview
@testable import WaylandRaw

@Suite
struct GBMSurfaceTests {
    @Test
    func surfaceDescriptorCapturesDmabufSelection() throws {
        let size = try GBMBufferSize(width: 320, height: 240)
        let formatModifier = RawLinuxDmabufFormatModifier(
            format: GBMDRMFormat.xrgb8888,
            modifier: GBMDRMModifier.invalid
        )

        let descriptor = GBMSurfaceDescriptor(
            size: size,
            formatModifier: formatModifier,
            flags: [.rendering, .linear]
        )

        #expect(descriptor.size == size)
        #expect(descriptor.format == GBMDRMFormat.xrgb8888)
        #expect(descriptor.modifier == GBMDRMModifier.invalid)
        #expect(descriptor.flags == [.rendering, .linear])
    }
}
