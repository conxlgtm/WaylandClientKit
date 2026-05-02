public enum DisplayOperationError: Error, Equatable, Sendable, CustomStringConvertible {
    case closed
    case unknownWindow(WindowID)

    public var description: String {
        switch self {
        case .closed:
            "display is closed"
        case .unknownWindow(let windowID):
            "unknown window: \(windowID)"
        }
    }
}

public enum PointerCursorOperation: Equatable, Sendable, CustomStringConvertible {
    case setHidden
    case setNamed

    public var description: String {
        switch self {
        case .setHidden:
            "set hidden cursor"
        case .setNamed:
            "set named cursor"
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
    public let operation: PointerCursorOperation
    public let seatID: SeatID
    public let requestedCursor: PointerCursor
    public let backendResult: PointerCursorBackendResult

    public init(
        operation cursorOperation: PointerCursorOperation,
        seatID cursorSeatID: SeatID,
        requestedCursor cursor: PointerCursor,
        backendResult result: PointerCursorBackendResult
    ) {
        operation = cursorOperation
        seatID = cursorSeatID
        requestedCursor = cursor
        backendResult = result
    }

    public var description: String {
        "\(operation.description) failed for seat \(seatID): \(backendResult.description)"
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
