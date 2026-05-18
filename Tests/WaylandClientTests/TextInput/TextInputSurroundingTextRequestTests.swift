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
    func stringIndexInitializerUsesUTF8Offsets() throws {
        let text = "aé🙂中"
        let cursor = try #require(text.firstIndex(of: "🙂"))
        let anchor = try #require(text.firstIndex(of: "中"))

        let surroundingText = try TextInputSurroundingText(
            text: text,
            cursor: cursor,
            anchor: anchor
        )

        #expect(surroundingText.cursorUTF8Offset == 3)
        #expect(surroundingText.anchorUTF8Offset == 7)
    }

    @Test
    func insertionPointUsesSameCursorAndAnchorOffset() throws {
        let text = "Cafe\u{301}"
        let cursor = text.endIndex

        let surroundingText = try TextInputSurroundingText.insertionPoint(
            text,
            cursor: cursor
        )

        #expect(surroundingText.cursorUTF8Offset == text.utf8.count)
        #expect(surroundingText.anchorUTF8Offset == text.utf8.count)
    }

    @Test
    func stringIndexInitializerRejectsOutOfBoundsIndex() {
        let longer = "abcdef"
        let staleIndex = longer.index(longer.startIndex, offsetBy: 5)

        #expect(throws: TextInputError.surroundingTextIndexOutOfBounds) {
            _ = try TextInputSurroundingText(
                text: "abc",
                cursor: staleIndex,
                anchor: "abc".startIndex
            )
        }
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
    func rejectsTextAboveProtocolByteLimit() {
        let text = String(
            repeating: "a",
            count: TextInputSurroundingText.maximumUTF8ByteCount + 1
        )

        #expect(
            throws: TextInputError.surroundingTextTooLarge(
                byteCount: TextInputSurroundingText.maximumUTF8ByteCount + 1,
                limit: TextInputSurroundingText.maximumUTF8ByteCount
            )
        ) {
            _ = try TextInputSurroundingText(
                text: text,
                cursorUTF8Offset: 0,
                anchorUTF8Offset: 0
            )
        }
    }

    @Test
    func acceptsTextAtProtocolByteLimit() throws {
        let text = String(
            repeating: "a",
            count: TextInputSurroundingText.maximumUTF8ByteCount
        )

        let surroundingText = try TextInputSurroundingText(
            text: text,
            cursorUTF8Offset: TextInputSurroundingText.maximumUTF8ByteCount,
            anchorUTF8Offset: 0
        )

        let request = try TextInputSurroundingTextRequest(surroundingText)
        #expect(request.text == text)
        #expect(request.cursorByteOffset == 4_000)
        #expect(request.anchorByteOffset == 0)
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
    func rejectsCursorOffsetInsideUTF8CodePoint() {
        #expect(
            throws: TextInputError.surroundingTextOffsetInsideCodePoint(offset: 2)
        ) {
            _ = try TextInputSurroundingText(
                text: "aéz",
                cursorUTF8Offset: 2,
                anchorUTF8Offset: 0
            )
        }
    }

    @Test
    func rejectsAnchorOffsetInsideUTF8CodePoint() {
        #expect(
            throws: TextInputError.surroundingTextOffsetInsideCodePoint(offset: 2)
        ) {
            _ = try TextInputSurroundingText(
                text: "aéz",
                cursorUTF8Offset: 0,
                anchorUTF8Offset: 2
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
