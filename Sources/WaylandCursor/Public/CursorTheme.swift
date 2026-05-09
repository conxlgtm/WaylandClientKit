import CWaylandCursorShims
import WaylandRaw

@safe
package final class CursorTheme {
    @safe private let pointer: OpaquePointer

    package init(shm: RawSharedMemory, name: String?, size: Int32) throws {
        guard size > 0 else {
            throw CursorError.invalidSize(size)
        }

        let loadedTheme: OpaquePointer?
        if let name {
            unsafe loadedTheme = name.withCString { namePointer in
                unsafe swl_cursor_theme_load(
                    namePointer,
                    size,
                    shm.pointer
                )
            }
        } else {
            unsafe loadedTheme = swl_cursor_theme_load(nil, size, shm.pointer)
        }

        guard let loadedTheme = unsafe loadedTheme else {
            throw CursorError.themeLoadFailed
        }

        unsafe pointer = loadedTheme
    }

    package func cursorImage(named name: String) throws -> CursorImage {
        let cursorPointer = unsafe name.withCString { namePointer in
            unsafe swl_cursor_theme_get_cursor(pointer, namePointer)
        }

        guard let cursorPointer = unsafe cursorPointer else {
            throw CursorError.missingCursor(name)
        }

        guard unsafe swl_cursor_image_count(cursorPointer) > 0,
            let imagePointer = unsafe swl_cursor_image_at(cursorPointer, 0)
        else {
            throw CursorError.missingImage(name)
        }

        guard let bufferPointer = unsafe swl_cursor_image_get_buffer(imagePointer) else {
            throw CursorError.missingBuffer(name)
        }

        return try CursorImage(
            width: unsafe swl_cursor_image_width(imagePointer),
            height: unsafe swl_cursor_image_height(imagePointer),
            hotspotX: unsafe swl_cursor_image_hotspot_x(imagePointer),
            hotspotY: unsafe swl_cursor_image_hotspot_y(imagePointer),
            delay: unsafe swl_cursor_image_delay(imagePointer),
            buffer: RawBorrowedBuffer(pointer: bufferPointer),
            owner: self
        )
    }

    deinit {
        unsafe swl_cursor_theme_destroy(pointer)
    }
}

package final class CursorImage {
    package let width: Int32
    package let height: Int32
    package let hotspotX: Int32
    package let hotspotY: Int32
    package let delay: UInt32
    package let buffer: RawBorrowedBuffer
    private let owner: CursorTheme?

    package init(
        width imageWidth: UInt32,
        height imageHeight: UInt32,
        hotspotX imageHotspotX: UInt32,
        hotspotY imageHotspotY: UInt32,
        delay imageDelay: UInt32,
        buffer imageBuffer: RawBorrowedBuffer,
        owner imageOwner: CursorTheme? = nil
    ) throws {
        width = try Self.int32(imageWidth)
        height = try Self.int32(imageHeight)
        hotspotX = try Self.int32(imageHotspotX)
        hotspotY = try Self.int32(imageHotspotY)
        delay = imageDelay
        buffer = imageBuffer
        owner = imageOwner
    }

    private static func int32(_ value: UInt32) throws -> Int32 {
        guard value <= UInt32(Int32.max) else {
            throw CursorError.invalidImageDimension(value)
        }

        return Int32(value)
    }
}
