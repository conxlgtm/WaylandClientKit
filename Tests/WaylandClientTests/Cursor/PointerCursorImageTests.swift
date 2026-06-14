import Testing

@testable import WaylandClient

@Suite
struct PointerCursorImageTests {
    @Test
    func customCursorImageAcceptsMatchingPixelsAndHotspot() throws {
        let size = try PositivePixelSize(width: 2, height: 3)
        let image = try PointerCursorImage(
            size: size,
            hotspotX: 1,
            hotspotY: 2,
            pixels: Array(repeating: 0x00FF_00FF, count: 6)
        )

        #expect(image.size == size)
        #expect(image.hotspotX == 1)
        #expect(image.hotspotY == 2)
        #expect(image.pixels.count == 6)
        #expect(PointerCursor.image(image).image == image)
    }

    @Test
    func customCursorImageRejectsWrongPixelCount() throws {
        let size = try PositivePixelSize(width: 2, height: 3)

        #expect(
            throws: ClientError.cursor(
                .invalidConfiguration(.invalidCursorImagePixelCount(expected: 6, actual: 5))
            )
        ) {
            _ = try PointerCursorImage(
                size: size,
                hotspotX: 0,
                hotspotY: 0,
                pixels: Array(repeating: 0x0000_0000, count: 5)
            )
        }
    }

    @Test
    func customCursorImageRejectsHotspotOutsideImage() throws {
        let size = try PositivePixelSize(width: 2, height: 3)

        #expect(
            throws: ClientError.cursor(
                .invalidConfiguration(
                    .cursorImageHotspotOutsideBounds(x: 2, y: 1, width: 2, height: 3)
                )
            )
        ) {
            _ = try PointerCursorImage(
                size: size,
                hotspotX: 2,
                hotspotY: 1,
                pixels: Array(repeating: 0x0000_0000, count: 6)
            )
        }
    }

    @Test
    func solidCustomCursorImageFillsEveryPixel() throws {
        let image = try PointerCursorImage.solid(
            size: PositivePixelSize(width: 3, height: 2),
            hotspotX: 1,
            hotspotY: 1,
            color: 0x0012_3456
        )

        #expect(image.pixels == Array(repeating: 0x0012_3456, count: 6))
        #expect(image.hotspotX == 1)
        #expect(image.hotspotY == 1)
    }

    @Test
    func pointerCursorFrameRejectsNonPositiveDuration() throws {
        let image = try PointerCursorImage.solid(
            size: PositivePixelSize(width: 2, height: 2),
            color: 0x0000_0000
        )

        #expect(
            throws: ClientError.cursor(
                .invalidConfiguration(.nonPositiveCursorFrameDuration(.zero))
            )
        ) {
            _ = try PointerCursorFrame(image: image, duration: .zero)
        }
    }

    @Test
    func animatedPointerCursorRejectsEmptyFrameSet() {
        #expect(
            throws: ClientError.cursor(.invalidConfiguration(.emptyCursorAnimation))
        ) {
            _ = try AnimatedPointerCursor(frames: [])
        }
    }

    @Test
    func animatedPointerCursorStoresValidatedFrames() throws {
        let image = try PointerCursorImage.solid(
            size: PositivePixelSize(width: 2, height: 2),
            hotspotX: 1,
            hotspotY: 1,
            color: 0x00FF_0000
        )
        let frame = try PointerCursorFrame(image: image, duration: .milliseconds(50))
        let animation = try AnimatedPointerCursor(frames: [frame])
        let cursor = try PointerCursor.animated(animation)

        #expect(animation.frames == [frame])
        #expect(cursor.animation == animation)
        #expect(cursor.image == nil)
    }
}
