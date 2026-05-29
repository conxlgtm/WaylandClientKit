public enum DisplayOperationError: Error, Equatable, Sendable, CustomStringConvertible {
    case closed
    case unknownWindow(WindowID)
    case unknownPopup
    case unknownSubsurface(SubsurfaceIdentity)
    case closedPopup
    case closedSubsurface
    case foreignWindow(WindowID)
    case foreignSubsurface(SubsurfaceIdentity)
    case presentationTimeUnavailable

    public var description: String {
        switch self {
        case .closed:
            "display is closed"
        case .unknownWindow(let windowID):
            "unknown window: \(windowID)"
        case .unknownPopup:
            "unknown popup"
        case .unknownSubsurface(let subsurfaceID):
            "unknown subsurface: \(subsurfaceID)"
        case .closedPopup:
            "popup is closed"
        case .closedSubsurface:
            "subsurface is closed"
        case .foreignWindow(let windowID):
            "window belongs to another display: \(windowID)"
        case .foreignSubsurface(let subsurfaceID):
            "subsurface belongs to another display: \(subsurfaceID)"
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
