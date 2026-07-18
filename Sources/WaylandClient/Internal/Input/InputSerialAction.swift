package typealias InputSerialActionHandler =
    @Sendable (InputEvent, InputSerialActionContext) -> Void

package struct InputSerialActionContext {
    private unowned let core: DisplayCore

    init(core displayCore: DisplayCore) {
        core = displayCore
    }

    @discardableResult
    package func setPointerCursor(_ cursor: PointerCursor) throws -> [CursorRequestResult] {
        try core.setPointerCursor(cursor)
    }

    package func requestRedraw(_ windowID: WindowID) throws {
        try core.requestRedraw(windowID)
    }

    package func windowGeometry(_ windowID: WindowID) throws -> SurfaceGeometry {
        try core.windowGeometry(windowID)
    }

    package func requestInteractiveMove(
        _ windowID: WindowID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try core.requestWindowInteractiveMove(
            windowID,
            seatID: seatID,
            serial: serial
        )
    }

    package func requestInteractiveResize(
        _ windowID: WindowID,
        seatID: SeatID,
        serial: InputSerial,
        edge: WindowResizeEdge
    ) throws {
        try core.requestWindowInteractiveResize(
            windowID,
            seatID: seatID,
            serial: serial,
            edge: edge
        )
    }
}
