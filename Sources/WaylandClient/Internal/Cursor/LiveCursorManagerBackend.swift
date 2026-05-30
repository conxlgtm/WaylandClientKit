import WaylandCursor
import WaylandRaw

final class LiveCursorManagerBackend: CursorManagerBackend {
    private let connection: RawDisplayConnection
    private let configuration: CursorConfiguration
    private var themesBySize: [CursorSize: CursorTheme] = [:]

    init(
        connection rawConnection: RawDisplayConnection,
        configuration cursorConfiguration: CursorConfiguration
    ) throws {
        rawConnection.preconditionIsOwnerThread()

        connection = rawConnection
        configuration = cursorConfiguration
    }

    func preconditionIsOwnerThread() {
        connection.preconditionIsOwnerThread()
    }

    var supportsCursorShape: Bool {
        connection.supportsCursorShape
    }

    func cursorImage(named name: String, size: CursorSize) throws -> CursorImage {
        try cursorTheme(size: size).cursorImage(named: name)
    }

    func cursorImage(from image: PointerCursorImage) throws -> CursorImage {
        let pool = try connection.cursorSharedMemory().createPool(
            width: image.size.width.rawValue,
            height: image.size.height.rawValue,
            bufferCount: 1
        )
        guard var drawingBuffer = pool.acquireDrawingBuffer() else {
            throw CursorError.missingBuffer("custom cursor image")
        }

        do {
            try unsafe drawingBuffer.withUnsafeMutableBytes { bytes in
                try unsafe image.pixels.withUnsafeBytes { sourceBytes in
                    guard sourceBytes.count <= bytes.count else {
                        throw ClientError.cursor(
                            .invalidConfiguration(
                                .invalidCursorImagePixelCount(
                                    expected: image.pixels.count,
                                    actual: bytes.count / MemoryLayout<UInt32>.stride
                                )
                            ))
                    }

                    unsafe bytes.copyMemory(from: sourceBytes)
                }
            }

            let buffer = drawingBuffer.markBusy(commitGeneration: 0)
            return try CursorImage(
                width: image.size.width.rawValue,
                height: image.size.height.rawValue,
                hotspotX: image.hotspotX,
                hotspotY: image.hotspotY,
                delay: 0,
                buffer: buffer,
                owner: pool
            )
        } catch {
            drawingBuffer.discard()
            throw error
        }
    }

    func createCursorSurface(for _: RawSeatID) throws -> CursorManagerSurface {
        try CursorRoleSurface(surface: connection.createRawSurface())
    }

    func setPointerCursor(
        seatID: RawSeatID,
        serial: UInt32,
        surface: CursorManagerSurface?,
        hotspotX: Int32,
        hotspotY: Int32
    ) -> RawPointerCursorResult {
        let rawSurface: RawSurface?
        if let surface {
            guard let liveSurface = surface as? CursorRoleSurface else {
                preconditionFailure("Live cursor backend received a non-live cursor surface")
            }
            rawSurface = liveSurface.rawSurface
        } else {
            rawSurface = nil
        }

        return connection.setPointerCursor(
            seatID: seatID,
            serial: serial,
            surface: rawSurface,
            hotspotX: hotspotX,
            hotspotY: hotspotY
        )
    }

    func setPointerCursorShape(
        seatID: RawSeatID,
        serial: UInt32,
        shape: RawCursorShapeName
    ) throws -> RawPointerCursorResult {
        try connection.setPointerCursorShape(
            seatID: seatID,
            serial: serial,
            shape: shape
        )
    }

    private func cursorTheme(size: CursorSize) throws -> CursorTheme {
        if let theme = themesBySize[size] {
            return theme
        }

        let loadedTheme = try CursorTheme(
            shm: connection.cursorSharedMemory(),
            name: configuration.themeName?.value,
            size: size.rawValue
        )
        themesBySize[size] = loadedTheme
        return loadedTheme
    }
}
