public enum PointerWarpError: Error, Equatable, Sendable, CustomStringConvertible {
    case unavailable
    case displayClosed
    case foreignWindow(WindowID)
    case unknownWindow(WindowID)
    case closedWindow(WindowID)
    case unknownSeat(SeatID)
    case pointerUnavailable(SeatID)
    case invalidPosition(position: LogicalOffset, windowSize: PositiveLogicalSize)
    case requestFailed(String)

    public var description: String {
        switch self {
        case .unavailable:
            "pointer-warp protocol is unavailable"
        case .displayClosed:
            "display is closed"
        case .foreignWindow(let windowID):
            "window \(windowID) belongs to another display"
        case .unknownWindow(let windowID):
            "unknown window \(windowID)"
        case .closedWindow(let windowID):
            "window \(windowID) is closed"
        case .unknownSeat(let seatID):
            "unknown seat \(seatID)"
        case .pointerUnavailable(let seatID):
            "seat \(seatID) has no pointer device"
        case .invalidPosition(let position, let windowSize):
            "pointer warp position \(position) is outside window size \(windowSize)"
        case .requestFailed(let detail):
            "pointer warp request failed: \(detail)"
        }
    }
}
