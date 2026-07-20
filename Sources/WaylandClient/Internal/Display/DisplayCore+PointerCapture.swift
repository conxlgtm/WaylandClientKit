import WaylandRaw

extension DisplayCore {
    func createRelativePointerSubscription(
        seatID: SeatID
    ) throws -> RelativePointerSubscriptionID {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw PointerCaptureError.displayClosed
            }

            return try requireSession().pointerCaptureManager.createRelativePointer(
                seatID: seatID
            )
        }
    }

    func createPointerGestureSubscription(
        seatID: SeatID
    ) throws -> (id: PointerGestureSubscriptionID, version: UInt32) {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw PointerCaptureError.displayClosed
            }

            return try requireSession().pointerCaptureManager.createPointerGestures(
                seatID: seatID
            )
        }
    }

    func lockPointer(
        windowID: WindowID,
        seatID: SeatID,
        cursorHint: PointerLocation?,
        region: PointerConstraintRegion?,
        lifetime: PointerConstraintLifetime
    ) throws -> PointerConstraintID {
        try withFatalFailureFinalization {
            let surface = try pointerCaptureWindowSurface(windowID)
            return try requireSession().pointerCaptureManager.lockPointer(
                surface: surface,
                seatID: seatID,
                cursorHint: cursorHint,
                region: region,
                lifetime: lifetime
            )
        }
    }

    func confinePointer(
        windowID: WindowID,
        seatID: SeatID,
        region: PointerConstraintRegion?,
        lifetime: PointerConstraintLifetime
    ) throws -> PointerConstraintID {
        try withFatalFailureFinalization {
            let surface = try pointerCaptureWindowSurface(windowID)
            return try requireSession().pointerCaptureManager.confinePointer(
                surface: surface,
                seatID: seatID,
                region: region,
                lifetime: lifetime
            )
        }
    }

    func requestPointerWarp(
        windowID: WindowID,
        seatID: SeatID,
        position: LogicalOffset,
        serial: InputSerial
    ) throws {
        try withFatalFailureFinalization {
            let window = surfaces.window(windowID)
            try Self.validatePointerWarpWindowState(
                isDisplayClosed: isClosed,
                windowID: windowID,
                windowExists: window != nil,
                windowIsClosed: window?.isClosedOnOwnerThread ?? false
            )
            guard let window else {
                throw PointerWarpError.unknownWindow(windowID)
            }

            let geometry: SurfaceGeometry
            do {
                geometry = try window.geometryOnOwnerThread
            } catch {
                throw PointerWarpError.requestFailed(String(describing: error))
            }

            try requireSession().pointerCaptureManager.requestPointerWarp(
                surface: window.rawSurfaceOnOwnerThread,
                windowSize: geometry.logicalSize,
                seatID: seatID,
                position: position,
                serial: serial
            )
        }
    }

    package static func validatePointerWarpWindowState(
        isDisplayClosed: Bool,
        windowID: WindowID,
        windowExists: Bool,
        windowIsClosed: Bool
    ) throws {
        guard !isDisplayClosed else {
            throw PointerWarpError.displayClosed
        }
        guard windowExists else {
            throw PointerWarpError.unknownWindow(windowID)
        }
        guard !windowIsClosed else {
            throw PointerWarpError.closedWindow(windowID)
        }
    }

    func destroyRelativePointerSubscription(_ id: RelativePointerSubscriptionID) throws {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw PointerCaptureError.displayClosed
            }

            try requireSession().pointerCaptureManager.destroyRelativePointerSubscription(id)
        }
    }

    func destroyPointerGestureSubscription(_ id: PointerGestureSubscriptionID) throws {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw PointerCaptureError.displayClosed
            }

            try requireSession().pointerCaptureManager.destroyPointerGestureSubscription(id)
        }
    }

    func destroyPointerConstraint(_ id: PointerConstraintID) throws {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw PointerCaptureError.displayClosed
            }

            try requireSession().pointerCaptureManager.destroyPointerConstraint(id)
        }
    }

    private func pointerCaptureWindowSurface(_ windowID: WindowID) throws -> RawSurface {
        guard !isClosed else {
            throw PointerCaptureError.displayClosed
        }
        guard let window = surfaces.window(windowID) else {
            throw PointerCaptureError.unknownWindow(windowID)
        }
        guard !window.isClosedOnOwnerThread else {
            throw PointerCaptureError.closedWindow(windowID)
        }

        return window.rawSurfaceOnOwnerThread
    }
}
