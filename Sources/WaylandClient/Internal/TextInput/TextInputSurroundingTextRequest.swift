private let maximumTextInputByteOffset = Int(Int32.max)

package struct TextInputSurroundingTextRequest: Equatable, Sendable {
    package let text: String
    package let cursorByteOffset: Int32
    package let anchorByteOffset: Int32

    package init(_ request: TextInputSurroundingText) throws(TextInputError) {
        text = request.text
        cursorByteOffset = try Self.byteOffset(request.cursorUTF8Offset)
        anchorByteOffset = try Self.byteOffset(request.anchorUTF8Offset)
    }

    private static func byteOffset(_ count: Int) throws(TextInputError) -> Int32 {
        guard count <= maximumTextInputByteOffset else {
            throw .surroundingTextOffsetOverflow(byteCount: count)
        }

        return Int32(count)
    }
}
