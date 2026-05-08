public enum CursorRequestResult: Equatable, Sendable {
    case set(seatID: SeatID, serial: UInt32, cursor: PointerCursor)
    case hidden(seatID: SeatID, serial: UInt32)
    case skippedNoPointerFocus(seatID: SeatID)
}
