import Testing

@testable import WaylandClient

@Suite
struct TextInputSurroundingTextRequestTests {
    @Test
    func byteOffsetsUseUTF8Positions() throws {
        let text = "aéz"
        let surroundingText = try TextInputSurroundingText(
            text: text,
            cursorUTF8Offset: 3,
            anchorUTF8Offset: 4
        )
        let request = try TextInputSurroundingTextRequest(surroundingText)

        #expect(request.text == text)
        #expect(request.cursorByteOffset == 3)
        #expect(request.anchorByteOffset == 4)
    }

    @Test
    func rejectsNULByte() {
        let text = "abc\0def"

        #expect(throws: TextInputError.surroundingTextContainsNUL) {
            _ = try TextInputSurroundingText(
                text: text,
                cursorUTF8Offset: 0,
                anchorUTF8Offset: 3
            )
        }
    }

    @Test
    func rejectsCursorOffsetPastUTF8Count() {
        #expect(
            throws: TextInputError.surroundingTextOffsetOutOfBounds(
                offset: 4,
                byteCount: 3
            )
        ) {
            _ = try TextInputSurroundingText(
                text: "abc",
                cursorUTF8Offset: 4,
                anchorUTF8Offset: 0
            )
        }
    }

    @Test
    func rejectsAnchorOffsetPastUTF8Count() {
        #expect(
            throws: TextInputError.surroundingTextOffsetOutOfBounds(
                offset: 5,
                byteCount: 3
            )
        ) {
            _ = try TextInputSurroundingText(
                text: "abc",
                cursorUTF8Offset: 0,
                anchorUTF8Offset: 5
            )
        }
    }

    @Test
    func rejectsOffsetAboveInt32Max() {
        let overflowOffset = Int(Int32.max) + 1

        #expect(
            throws: TextInputError.surroundingTextOffsetOverflow(
                byteCount: overflowOffset
            )
        ) {
            _ = try TextInputSurroundingText(
                text: "",
                cursorUTF8Offset: overflowOffset,
                anchorUTF8Offset: 0
            )
        }
    }
}
