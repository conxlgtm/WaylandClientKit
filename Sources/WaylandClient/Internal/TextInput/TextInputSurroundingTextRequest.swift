private let maximumTextInputByteOffset = Int(Int32.max)

package struct TextInputSurroundingTextRequest: Equatable, Sendable {
    package let text: String
    package let cursorByteOffset: Int32
    package let anchorByteOffset: Int32

    package init(
        text requestText: String,
        cursor cursorIndex: String.Index,
        anchor anchorIndex: String.Index
    ) throws(TextInputError) {
        guard !requestText.utf8.contains(0) else {
            throw .surroundingTextContainsNUL
        }

        text = requestText
        cursorByteOffset = try Self.byteOffset(in: requestText, for: cursorIndex)
        anchorByteOffset = try Self.byteOffset(in: requestText, for: anchorIndex)
    }

    private static func byteOffset(
        in text: String,
        for index: String.Index
    ) throws(TextInputError) -> Int32 {
        let count = text[..<index].utf8.count
        guard count <= maximumTextInputByteOffset else {
            throw .surroundingTextOffsetOverflow(byteCount: count)
        }

        return Int32(count)
    }
}
