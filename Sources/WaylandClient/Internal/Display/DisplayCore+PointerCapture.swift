import WaylandRaw

extension DisplayCore {
    func createRelativePointerSubscription(
        seatID: SeatID
    ) throws -> RelativePointerSubscriptionID {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw PointerCaptureError.displayClosed
            }

            return try requireSession().createRelativePointerOnOwnerThread(seatID: seatID)
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
            return try requireSession().lockPointerOnOwnerThread(
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
            return try requireSession().confinePointerOnOwnerThread(
                surface: surface,
                seatID: seatID,
                region: region,
                lifetime: lifetime
            )
        }
    }

    func destroyRelativePointerSubscription(_ id: RelativePointerSubscriptionID) throws {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw PointerCaptureError.displayClosed
            }

            try requireSession().destroyRelativePointerSubscriptionOnOwnerThread(id)
        }
    }

    func destroyPointerConstraint(_ id: PointerConstraintID) throws {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw PointerCaptureError.displayClosed
            }

            try requireSession().destroyPointerConstraintOnOwnerThread(id)
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
