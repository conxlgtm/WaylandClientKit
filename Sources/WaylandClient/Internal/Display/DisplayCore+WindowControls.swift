extension DisplayCore {
    func windowStateSnapshot(_ windowID: WindowID) throws -> WindowStateSnapshot {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).stateSnapshotOnOwnerThread
        }
    }

    func setWindowTitle(_ windowID: WindowID, _ title: WaylandString) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).setTitleOnOwnerThread(title)
        }
    }

    func setWindowAppID(_ windowID: WindowID, _ appID: NonEmptyWaylandString) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).setAppIDOnOwnerThread(appID)
        }
    }

    func setWindowMinimumSize(_ windowID: WindowID, _ size: PositiveLogicalSize?) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).setMinimumSizeOnOwnerThread(size)
        }
    }

    func setWindowMaximumSize(_ windowID: WindowID, _ size: PositiveLogicalSize?) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).setMaximumSizeOnOwnerThread(size)
        }
    }

    func requestWindowMaximize(_ windowID: WindowID) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).requestMaximizeOnOwnerThread()
        }
    }

    func requestWindowUnmaximize(_ windowID: WindowID) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).requestUnmaximizeOnOwnerThread()
        }
    }

    func requestWindowFullscreen(_ windowID: WindowID) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).requestFullscreenOnOwnerThread()
        }
    }

    func requestWindowExitFullscreen(_ windowID: WindowID) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).requestExitFullscreenOnOwnerThread()
        }
    }

    func requestWindowMinimize(_ windowID: WindowID) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).requestMinimizeOnOwnerThread()
        }
    }

    func requestWindowInteractiveMove(
        _ windowID: WindowID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).requestInteractiveMoveOnOwnerThread(
                seatID: seatID,
                serial: serial
            )
        }
    }

    func requestWindowInteractiveResize(
        _ windowID: WindowID,
        seatID: SeatID,
        serial: InputSerial,
        edge: WindowResizeEdge
    ) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).requestInteractiveResizeOnOwnerThread(
                seatID: seatID,
                serial: serial,
                edge: edge
            )
        }
    }

    func requestWindowMenu(
        _ windowID: WindowID,
        seatID: SeatID,
        serial: InputSerial,
        position: LogicalOffset
    ) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).requestWindowMenuOnOwnerThread(
                seatID: seatID,
                serial: serial,
                position: position
            )
        }
    }
}
