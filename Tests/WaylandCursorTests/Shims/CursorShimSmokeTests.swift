import CWaylandCursorShims
import Testing

@Suite
struct CursorShimSmokeTests {
    @Test
    func cursorThemeShimsImportIntoSwift() {
        let load = unsafe swl_cursor_theme_load
        let destroy = unsafe swl_cursor_theme_destroy
        let getCursor = unsafe swl_cursor_theme_get_cursor
        let imageAt = unsafe swl_cursor_image_at
        let getBuffer = unsafe swl_cursor_image_get_buffer

        let loadSize = unsafe MemoryLayout.size(ofValue: load)
        let destroySize = unsafe MemoryLayout.size(ofValue: destroy)
        let getCursorSize = unsafe MemoryLayout.size(ofValue: getCursor)
        let imageAtSize = unsafe MemoryLayout.size(ofValue: imageAt)
        let getBufferSize = unsafe MemoryLayout.size(ofValue: getBuffer)

        #expect(loadSize > 0)
        #expect(destroySize > 0)
        #expect(getCursorSize > 0)
        #expect(imageAtSize > 0)
        #expect(getBufferSize > 0)
    }

    @Test
    func cursorImageShimsTreatNullInputsAsMissingValues() {
        let imageCount = swl_cursor_image_count(nil)
        let imageAtIsNil = unsafe swl_cursor_image_at(nil, 0) == nil
        let imageWidth = swl_cursor_image_width(nil)
        let imageHeight = swl_cursor_image_height(nil)
        let hotspotX = swl_cursor_image_hotspot_x(nil)
        let hotspotY = swl_cursor_image_hotspot_y(nil)
        let delay = swl_cursor_image_delay(nil)
        let bufferIsNil = unsafe swl_cursor_image_get_buffer(nil) == nil

        #expect(imageCount == 0)
        #expect(imageAtIsNil)
        #expect(imageWidth == 0)
        #expect(imageHeight == 0)
        #expect(hotspotX == 0)
        #expect(hotspotY == 0)
        #expect(delay == 0)
        #expect(bufferIsNil)
    }
}
