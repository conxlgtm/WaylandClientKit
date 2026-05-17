import Testing

@testable import WaylandClient

@Suite
struct TextInputSurroundingTextRequestTests {
    @Test
    func byteOffsetsUseUTF8Positions() throws {
        let text = "aéz"
        let cursor = text.index(text.startIndex, offsetBy: 2)
        let anchor = text.endIndex

        let request = try TextInputSurroundingTextRequest(
            text: text,
            cursor: cursor,
            anchor: anchor
        )

        #expect(request.text == text)
        #expect(request.cursorByteOffset == 3)
        #expect(request.anchorByteOffset == 4)
    }

    @Test
    func rejectsNULByte() {
        let text = "abc\0def"

        #expect(throws: TextInputError.surroundingTextContainsNUL) {
            _ = try TextInputSurroundingTextRequest(
                text: text,
                cursor: text.startIndex,
                anchor: text.endIndex
            )
        }
    }
}
