import Testing

@testable import WaylandCursor

@Suite
struct CursorErrorTests {
    @Test
    func invalidSizeDescriptionIncludesValue() {
        #expect(
            CursorError.invalidSize(0).description == "Cursor size must be greater than zero, got 0"
        )
    }
}
