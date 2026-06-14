import Testing

@testable import WaylandClient

@Suite
struct WindowIconDomainTypesTests {
    @Test
    func windowIconNameRejectsEmptyValue() throws {
        #expect(throws: ClientError.display(.emptyWindowIconName)) {
            _ = try WindowIconName("")
        }
    }

    @Test
    func windowIconNameRejectsNUL() throws {
        #expect(throws: ClientError.display(.windowIconNameContainsNUL)) {
            _ = try WindowIconName("app\0icon")
        }
    }

    @Test
    func windowIconNameDescriptionUsesValue() throws {
        let name = try WindowIconName("org.waylandclientkit.Smoke")

        #expect(name.value == "org.waylandclientkit.Smoke")
        #expect(name.description == "org.waylandclientkit.Smoke")
    }

    @Test
    func windowIconImageAcceptsSquareMatchingPixels() throws {
        let size = try PositivePixelSize(width: 2, height: 2)
        let image = try WindowIconImage(
            size: size,
            pixels: Array(repeating: 0x00FF_0000, count: 4)
        )

        #expect(image.size == size)
        #expect(image.scale.rawValue == 1)
        #expect(image.pixels.count == 4)
    }

    @Test
    func windowIconImageRejectsNonSquareSize() throws {
        let size = try PositivePixelSize(width: 2, height: 3)

        #expect(
            throws: ClientError.display(
                .nonSquareWindowIconImage(width: 2, height: 3)
            )
        ) {
            _ = try WindowIconImage(
                size: size,
                pixels: Array(repeating: 0x0000_0000, count: 6)
            )
        }
    }

    @Test
    func windowIconImageRejectsWrongPixelCount() throws {
        let size = try PositivePixelSize(width: 3, height: 3)

        #expect(
            throws: ClientError.display(
                .invalidWindowIconImagePixelCount(expected: 9, actual: 8)
            )
        ) {
            _ = try WindowIconImage(
                size: size,
                pixels: Array(repeating: 0x0000_0000, count: 8)
            )
        }
    }

    @Test
    func solidWindowIconImageFillsEveryPixel() throws {
        let image = try WindowIconImage.solid(
            size: PositivePixelSize(width: 3, height: 3),
            color: 0x0012_3456
        )

        #expect(image.pixels == Array(repeating: 0x0012_3456, count: 9))
        #expect(image.scale.rawValue == 1)
    }
}
