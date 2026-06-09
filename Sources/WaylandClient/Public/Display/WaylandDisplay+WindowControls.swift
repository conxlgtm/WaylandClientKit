extension WaylandDisplay {
    package func windowStateSnapshot(_ windowID: WindowID) throws -> WindowStateSnapshot {
        try requireCore().windowStateSnapshot(windowID)
    }

    package func windowRestorationSnapshot(_ windowID: WindowID) throws
        -> WindowRestorationSnapshot
    {
        try requireCore().windowRestorationSnapshot(windowID)
    }

    package func setWindowTitle(_ windowID: WindowID, _ title: WaylandString) throws {
        try requireCore().setWindowTitle(windowID, title)
    }

    package func setWindowAppID(_ windowID: WindowID, _ appID: NonEmptyWaylandString) throws {
        try requireCore().setWindowAppID(windowID, appID)
    }

    package func setWindowMinimumSize(
        _ windowID: WindowID,
        _ size: PositiveLogicalSize?
    ) throws {
        try requireCore().setWindowMinimumSize(windowID, size)
    }

    package func setWindowMaximumSize(
        _ windowID: WindowID,
        _ size: PositiveLogicalSize?
    ) throws {
        try requireCore().setWindowMaximumSize(windowID, size)
    }

    package func requestWindowMaximize(_ windowID: WindowID) throws {
        try requireCore().requestWindowMaximize(windowID)
    }

    package func requestWindowUnmaximize(_ windowID: WindowID) throws {
        try requireCore().requestWindowUnmaximize(windowID)
    }

    package func requestWindowFullscreen(
        _ windowID: WindowID,
        output: OutputID? = nil
    ) throws {
        try requireCore().requestWindowFullscreen(windowID, output: output)
    }

    package func requestWindowExitFullscreen(_ windowID: WindowID) throws {
        try requireCore().requestWindowExitFullscreen(windowID)
    }

    package func requestWindowMinimize(_ windowID: WindowID) throws {
        try requireCore().requestWindowMinimize(windowID)
    }

    package func requestWindowInteractiveMove(
        _ windowID: WindowID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try requireCore().requestWindowInteractiveMove(
            windowID,
            seatID: seatID,
            serial: serial
        )
    }

    package func requestWindowInteractiveResize(
        _ windowID: WindowID,
        seatID: SeatID,
        serial: InputSerial,
        edge: WindowResizeEdge
    ) throws {
        try requireCore().requestWindowInteractiveResize(
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
        try requireCore().requestWindowMenu(
            windowID,
            seatID: seatID,
            serial: serial,
            position: position
        )
    }
}
