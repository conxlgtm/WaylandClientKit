package struct RawPointerCursorSetResult: Equatable, Sendable {
    package let seatID: RawSeatID
    package let serial: UInt32
    package let surfaceID: RawObjectID?
    package let hotspotX: Int32
    package let hotspotY: Int32

    package init(
        seatID pointerSeatID: RawSeatID,
        serial pointerEnterSerial: UInt32,
        surfaceID cursorSurfaceID: RawObjectID?,
        hotspotX cursorHotspotX: Int32,
        hotspotY cursorHotspotY: Int32
    ) {
        seatID = pointerSeatID
        serial = pointerEnterSerial
        surfaceID = cursorSurfaceID
        hotspotX = cursorHotspotX
        hotspotY = cursorHotspotY
    }
}

package enum RawPointerCursorResult: Equatable, Sendable {
    case set(RawPointerCursorSetResult)
    case skippedUnknownSeat(RawSeatID)
    case skippedNoPointer(RawSeatID)
}
