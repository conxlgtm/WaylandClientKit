extension RawDisplayConnection {
    package var supportsCursorShape: Bool {
        preconditionIsOwnerThread()

        guard let boundGlobals else { return false }
        return boundGlobals.extensions.cursorShapeManager.isBound
    }

    package func createRawSurface() throws -> RawSurface {
        preconditionIsOwnerThread()
        return try bindRequiredGlobals().compositor.createSurface()
    }

    package func cursorSharedMemory() throws -> RawSharedMemory {
        preconditionIsOwnerThread()
        return try bindRequiredGlobals().sharedMemory
    }

    package func setPointerCursor(
        seatID: RawSeatID,
        serial: UInt32,
        surface: RawSurface?,
        hotspotX: Int32,
        hotspotY: Int32
    ) -> RawPointerCursorResult {
        preconditionIsOwnerThread()

        guard let boundGlobals else { return .skippedUnknownSeat(seatID) }

        return unsafe boundGlobals.seatRegistry.setPointerCursor(
            seatID: seatID,
            serial: serial,
            surfacePointer: surface?.pointer,
            hotspotX: hotspotX,
            hotspotY: hotspotY
        )
    }

    package func setPointerCursorShape(
        seatID: RawSeatID,
        serial: UInt32,
        shape: RawCursorShapeName
    ) throws -> RawPointerCursorResult {
        preconditionIsOwnerThread()

        guard let boundGlobals else { return .skippedUnknownSeat(seatID) }
        guard
            case .bound(let cursorShapeManager) =
                boundGlobals.extensions.cursorShapeManager
        else {
            return .skippedUnknownSeat(seatID)
        }

        return try boundGlobals.seatRegistry.setPointerCursorShape(
            seatID: seatID,
            manager: cursorShapeManager,
            serial: serial,
            shape: shape
        )
    }
}
