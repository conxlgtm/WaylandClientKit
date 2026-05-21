import Testing

@testable import WaylandCursor

@Suite
struct CursorErrorTests {
    @Test(
        "Cursor errors have stable descriptions",
        arguments: [
            (
                CursorError.invalidSize(0),
                "Cursor size must be greater than zero, got 0"
            ),
            (
                CursorError.themeLoadFailed,
                "Cursor theme load failed"
            ),
            (
                CursorError.missingCursor("left_ptr"),
                "Cursor theme does not contain cursor: left_ptr"
            ),
            (
                CursorError.missingImage("left_ptr"),
                "Cursor has no images: left_ptr"
            ),
            (
                CursorError.missingBuffer("left_ptr"),
                "Cursor image has no Wayland buffer: left_ptr"
            ),
            (
                CursorError.invalidImageDimension(UInt32.max),
                "Cursor image dimension does not fit Int32: 4294967295"
            ),
        ]
    )
    func descriptionIncludesFailureContext(error: CursorError, description: String) {
        #expect(error.description == description)
    }
}
