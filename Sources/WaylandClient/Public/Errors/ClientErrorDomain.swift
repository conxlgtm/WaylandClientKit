public enum DisplayOperationError: Error, Equatable, Sendable, CustomStringConvertible {
    case closed
    case unknownWindow(WindowID)
    case unknownPopup
    case closedPopup
    case foreignWindow(WindowID)
    case presentationTimeUnavailable

    public var description: String {
        switch self {
        case .closed:
            "display is closed"
        case .unknownWindow(let windowID):
            "unknown window: \(windowID)"
        case .unknownPopup:
            "unknown popup"
        case .closedPopup:
            "popup is closed"
        case .foreignWindow(let windowID):
            "window belongs to another display: \(windowID)"
        case .presentationTimeUnavailable:
            "presentation-time protocol is unavailable"
        }
    }
}

public enum PointerCursorBackendResult: Equatable, Sendable, CustomStringConvertible {
    case skippedUnknownSeat
    case skippedNoPointer

    public var description: String {
        switch self {
        case .skippedUnknownSeat:
            "unknown seat"
        case .skippedNoPointer:
            "seat has no pointer"
        }
    }
}

public struct PointerCursorRequestFailure: Equatable, Sendable, CustomStringConvertible {
    public let seatID: SeatID
    public let requestedCursor: PointerCursor
    public let backendResult: PointerCursorBackendResult

    public init(
        seatID cursorSeatID: SeatID,
        requestedCursor cursor: PointerCursor,
        backendResult result: PointerCursorBackendResult
    ) {
        seatID = cursorSeatID
        requestedCursor = cursor
        backendResult = result
    }

    public var description: String {
        "\(operationDescription) failed for seat \(seatID): \(backendResult.description)"
    }

    private var operationDescription: String {
        switch requestedCursor.kind {
        case .hidden:
            "set hidden cursor"
        case .named:
            "set named cursor"
        }
    }
}

public enum PointerCursorError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidConfiguration(CursorConfigurationError)
    case requestFailed(PointerCursorRequestFailure)

    public var description: String {
        switch self {
        case .invalidConfiguration(let error):
            "invalid cursor configuration: \(error.description)"
        case .requestFailed(let failure):
            failure.description
        }
    }
}
