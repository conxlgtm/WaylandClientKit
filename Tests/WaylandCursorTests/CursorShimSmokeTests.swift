import CWaylandCursorShims
import Testing

@Suite
struct CursorShimSmokeTests {
    @Test
    func cursorThemeShimsImportIntoSwift() {
        let load = swl_cursor_theme_load
        let destroy = swl_cursor_theme_destroy
        let getCursor = swl_cursor_theme_get_cursor
        let imageAt = swl_cursor_image_at
        let getBuffer = swl_cursor_image_get_buffer

        #expect(MemoryLayout.size(ofValue: load) > 0)
        #expect(MemoryLayout.size(ofValue: destroy) > 0)
        #expect(MemoryLayout.size(ofValue: getCursor) > 0)
        #expect(MemoryLayout.size(ofValue: imageAt) > 0)
        #expect(MemoryLayout.size(ofValue: getBuffer) > 0)
    }
}
