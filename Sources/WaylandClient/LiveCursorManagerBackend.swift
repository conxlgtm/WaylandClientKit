import WaylandCursor
import WaylandRaw

final class LiveCursorManagerBackend: CursorManagerBackend {
    private let connection: RawDisplayConnection
    private let configuration: CursorConfiguration
    private var theme: CursorTheme?

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

    func cursorImage(named name: String) throws -> CursorImage {
        try cursorTheme().cursorImage(named: name)
    }

    func createCursorSurface(for _: RawSeatID) throws -> CursorManagerSurface {
        try LiveCursorManagerSurface(surface: connection.createRawSurface())
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
            guard let liveSurface = surface as? LiveCursorManagerSurface else {
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

    private func cursorTheme() throws -> CursorTheme {
        if let theme {
            return theme
        }

        let loadedTheme = try CursorTheme(
            shm: connection.cursorSharedMemory(),
            name: configuration.themeName?.value,
            size: configuration.size.rawValue
        )
        theme = loadedTheme
        return loadedTheme
    }
}

private final class LiveCursorManagerSurface: CursorManagerSurface {
    let rawSurface: RawSurface

    init(surface: RawSurface) {
        rawSurface = surface
    }

    var objectID: RawObjectID? {
        rawSurface.objectID
    }

    func attach(_ image: CursorImage) {
        unsafe rawSurface.attachBorrowedBuffer(image.buffer)
        rawSurface.damageFullBuffer(width: image.width, height: image.height)
    }

    func commit() {
        rawSurface.commit()
    }

    func destroy() {
        rawSurface.destroy()
    }
}
