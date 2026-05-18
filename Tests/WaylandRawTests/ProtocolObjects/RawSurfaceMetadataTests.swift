import Testing

@testable import WaylandRaw

@Suite
struct RawSurfaceMetadataTests {
    @Test
    func contentTypeValuesPreserveProtocolRawValues() {
        #expect(RawContentType.none.rawValue == 0)
        #expect(RawContentType.photo.rawValue == 1)
        #expect(RawContentType.video.rawValue == 2)
        #expect(RawContentType.game.rawValue == 3)
        #expect(RawContentType(rawValue: 99).rawValue == 99)
    }

    @Test
    func alphaMultiplierValuesPreserveBoundaries() {
        #expect(RawAlphaMultiplier.transparent.rawValue == 0)
        #expect(RawAlphaMultiplier.opaque.rawValue == UInt32.max)
        #expect(RawAlphaMultiplier(rawValue: 123).rawValue == 123)
    }

    @Test
    func presentationHintPreservesKnownAndFutureValues() {
        #expect(RawPresentationHint.vsync.rawValue == 0)
        #expect(RawPresentationHint.async.rawValue == 1)
        #expect(RawPresentationHint.unknown(44).rawValue == 44)
    }

    @Test
    func colorRepresentationValuesPreserveProtocolRawValues() {
        #expect(RawSurfaceAlphaMode.premultipliedElectrical.rawValue == 0)
        #expect(RawSurfaceAlphaMode.premultipliedOptical.rawValue == 1)
        #expect(RawSurfaceAlphaMode.straight.rawValue == 2)
        #expect(RawSurfaceAlphaMode(rawValue: 90).rawValue == 90)

        #expect(RawSurfaceMatrixCoefficients.identity.rawValue == 1)
        #expect(RawSurfaceMatrixCoefficients.bt709.rawValue == 2)
        #expect(RawSurfaceMatrixCoefficients.bt2020.rawValue == 6)
        #expect(RawSurfaceMatrixCoefficients(rawValue: 99).rawValue == 99)

        #expect(RawSurfaceQuantizationRange.full.rawValue == 1)
        #expect(RawSurfaceQuantizationRange.limited.rawValue == 2)
        #expect(RawSurfaceQuantizationRange(rawValue: 88).rawValue == 88)

        #expect(RawSurfaceChromaLocation.type0.rawValue == 1)
        #expect(RawSurfaceChromaLocation.type5.rawValue == 6)
        #expect(RawSurfaceChromaLocation(rawValue: 77).rawValue == 77)
    }

    @Test
    func renderIntentValuesPreserveProtocolRawValues() {
        #expect(RawColorRenderIntent.perceptual.rawValue == 0)
        #expect(RawColorRenderIntent.relative.rawValue == 1)
        #expect(RawColorRenderIntent.saturation.rawValue == 2)
        #expect(RawColorRenderIntent.absolute.rawValue == 3)
        #expect(RawColorRenderIntent.relativeBlackPointCompensation.rawValue == 4)
        #expect(RawColorRenderIntent.absoluteNoAdaptation.rawValue == 5)
        #expect(RawColorRenderIntent(rawValue: 66).rawValue == 66)
    }

    @Test
    func metadataSurfaceDestroyIsIdempotent() throws {
        let destroyCounter = DestroyCounter()
        let contentType = RawContentTypeSurface(
            pointer: try unsafe #require(OpaquePointer(bitPattern: 0xC001)),
            destroy: { pointer in
                unsafe destroyCounter.destroy(pointer)
            }
        )

        contentType.destroy()
        contentType.destroy()

        #expect(destroyCounter.count == 1)
    }

    @Test
    func imageDescriptionDestroyIsIdempotent() throws {
        let destroyCounter = DestroyCounter()
        let description = RawImageDescription(
            pointer: try unsafe #require(OpaquePointer(bitPattern: 0xC101)),
            destroy: { pointer in
                unsafe destroyCounter.destroy(pointer)
            }
        )

        description.destroy()
        description.destroy()

        #expect(destroyCounter.count == 1)
    }
}

private final class DestroyCounter {
    private(set) var count = 0

    func destroy(_: OpaquePointer) {
        count += 1
    }
}
