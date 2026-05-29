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
        guard let image = try cursorImages(named: name).first else {
            throw CursorError.missingImage(name)
        }

        return image
    }

    package func cursorImages(named name: String) throws -> [CursorImage] {
        let cursorPointer = unsafe name.withCString { namePointer in
            unsafe swl_cursor_theme_get_cursor(pointer, namePointer)
        }

        guard let cursorPointer = unsafe cursorPointer else {
            throw CursorError.missingCursor(name)
        }

        let imageCount = unsafe swl_cursor_image_count(cursorPointer)
        guard imageCount > 0 else {
            throw CursorError.missingImage(name)
        }

        var images: [CursorImage] = []
        images.reserveCapacity(Int(imageCount))

        for index in 0..<imageCount {
            guard let imagePointer = unsafe swl_cursor_image_at(cursorPointer, index) else {
                throw CursorError.missingImage(name)
            }

            guard let bufferPointer = unsafe swl_cursor_image_get_buffer(imagePointer) else {
                throw CursorError.missingBuffer(name)
            }

            try images.append(
                CursorImage(
                    width: unsafe swl_cursor_image_width(imagePointer),
                    height: unsafe swl_cursor_image_height(imagePointer),
                    hotspotX: unsafe swl_cursor_image_hotspot_x(imagePointer),
                    hotspotY: unsafe swl_cursor_image_hotspot_y(imagePointer),
                    delay: unsafe swl_cursor_image_delay(imagePointer),
                    buffer: RawBorrowedBuffer(pointer: bufferPointer),
                    owner: self
                ))
        }

        return images
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
    private let owner: AnyObject?

    package init(
        width imageWidth: UInt32,
        height imageHeight: UInt32,
        hotspotX imageHotspotX: UInt32,
        hotspotY imageHotspotY: UInt32,
        delay imageDelay: UInt32,
        buffer imageBuffer: RawBorrowedBuffer,
        owner imageOwner: AnyObject? = nil
    ) throws {
        width = try Self.int32(imageWidth)
        height = try Self.int32(imageHeight)
        hotspotX = try Self.int32(imageHotspotX)
        hotspotY = try Self.int32(imageHotspotY)
        delay = imageDelay
        buffer = imageBuffer
        owner = imageOwner
    }

    package init(
        width imageWidth: Int32,
        height imageHeight: Int32,
        hotspotX imageHotspotX: Int32,
        hotspotY imageHotspotY: Int32,
        delay imageDelay: UInt32,
        buffer imageBuffer: RawBuffer,
        owner imageOwner: AnyObject
    ) throws {
        guard imageWidth > 0 else {
            throw CursorError.invalidImageDimension(0)
        }
        guard imageHeight > 0 else {
            throw CursorError.invalidImageDimension(0)
        }

        width = imageWidth
        height = imageHeight
        hotspotX = imageHotspotX
        hotspotY = imageHotspotY
        delay = imageDelay
        buffer = RawBorrowedBuffer(pointer: imageBuffer.surfaceBuffer.pointer)
        owner = imageOwner
    }

    private static func int32(_ value: UInt32) throws -> Int32 {
        guard value <= UInt32(Int32.max) else {
            throw CursorError.invalidImageDimension(value)
        }

        return Int32(value)
    }
}
