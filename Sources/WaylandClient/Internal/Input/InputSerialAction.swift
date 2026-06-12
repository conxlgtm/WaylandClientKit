package struct InputSerialActionID: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(rawValue actionRawValue: UInt64) {
        rawValue = actionRawValue
    }

    package var description: String {
        "input-serial-action-\(rawValue)"
    }
}

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

    package func windowStateSnapshot(_ windowID: WindowID) throws -> WindowStateSnapshot {
        try core.windowStateSnapshot(windowID)
    }

    package func windowDecorationMode(_ windowID: WindowID) throws -> WindowDecorationMode {
        try core.windowDecorationMode(windowID)
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

    package func requestWindowMenu(
        _ windowID: WindowID,
        seatID: SeatID,
        serial: InputSerial,
        position: LogicalOffset
    ) throws {
        try core.requestWindowMenu(
            windowID,
            seatID: seatID,
            serial: serial,
            position: position
        )
    }
}
