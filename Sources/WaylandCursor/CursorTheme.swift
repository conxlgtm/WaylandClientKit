import CWaylandCursorShims
import WaylandRaw

public final class CursorTheme {
    private let pointer: OpaquePointer

    public init(shm: RawSharedMemory, name: String?, size: Int32) throws {
        guard size > 0 else {
            throw CursorError.invalidSize(size)
        }

        let loadedTheme: OpaquePointer?
        if let name {
            loadedTheme = name.withCString { namePointer in
                swl_cursor_theme_load(namePointer, size, shm.pointer)
            }
        } else {
            loadedTheme = swl_cursor_theme_load(nil, size, shm.pointer)
        }

        guard let loadedTheme else {
            throw CursorError.themeLoadFailed
        }

        pointer = loadedTheme
    }

    public func cursor(named name: String) throws -> Cursor {
        let cursorPointer = name.withCString { namePointer in
            swl_cursor_theme_get_cursor(pointer, namePointer)
        }

        guard let cursorPointer else {
            throw CursorError.missingCursor(name)
        }

        guard swl_cursor_image_count(cursorPointer) > 0,
            let imagePointer = swl_cursor_image_at(cursorPointer, 0)
        else {
            throw CursorError.missingImage(name)
        }

        guard let bufferPointer = swl_cursor_image_get_buffer(imagePointer) else {
            throw CursorError.missingBuffer(name)
        }

        let image = try CursorImage(
            width: swl_cursor_image_width(imagePointer),
            height: swl_cursor_image_height(imagePointer),
            hotspotX: swl_cursor_image_hotspot_x(imagePointer),
            hotspotY: swl_cursor_image_hotspot_y(imagePointer),
            delay: swl_cursor_image_delay(imagePointer),
            buffer: RawBorrowedBuffer(pointer: bufferPointer)
        )

        return Cursor(name: name, image: image)
    }

    deinit {
        swl_cursor_theme_destroy(pointer)
    }
}

public struct Cursor: Equatable {
    public let name: String
    public let image: CursorImage
}

public struct CursorImage: Equatable {
    public let width: Int32
    public let height: Int32
    public let hotspotX: Int32
    public let hotspotY: Int32
    public let delay: UInt32
    package let buffer: RawBorrowedBuffer

    package init(
        width imageWidth: UInt32,
        height imageHeight: UInt32,
        hotspotX imageHotspotX: UInt32,
        hotspotY imageHotspotY: UInt32,
        delay imageDelay: UInt32,
        buffer imageBuffer: RawBorrowedBuffer
    ) throws {
        width = try Self.int32(imageWidth)
        height = try Self.int32(imageHeight)
        hotspotX = try Self.int32(imageHotspotX)
        hotspotY = try Self.int32(imageHotspotY)
        delay = imageDelay
        buffer = imageBuffer
    }

    private static func int32(_ value: UInt32) throws -> Int32 {
        guard value <= UInt32(Int32.max) else {
            throw CursorError.invalidImageDimension(value)
        }

        return Int32(value)
    }
}
