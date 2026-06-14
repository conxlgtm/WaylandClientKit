public enum DisplayOperationError: Error, Equatable, Sendable, CustomStringConvertible {
    case closed
    case unknownWindow(WindowID)
    case unknownPopup
    case unknownSubsurface(SubsurfaceIdentity)
    case closedPopup
    case closedSubsurface
    case foreignWindow(WindowID)
    case foreignSubsurface(SubsurfaceIdentity)
    case invalidSubsurfaceStacking(SubsurfaceStackingError)
    case subsurfacePresentationFailed(SubsurfacePresentationFailure)
    case presentationTimeUnavailable
    case xdgToplevelIconUnavailable
    case idleInhibitUnavailable
    case systemBellUnavailable
    case unknownIdleInhibitor(IdleInhibitorID)
    case foreignIdleInhibitor(IdleInhibitorID)
    case emptyWindowIconName
    case windowIconNameContainsNUL
    case nonSquareWindowIconImage(width: Int32, height: Int32)
    case invalidWindowIconImagePixelCount(expected: Int, actual: Int)

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
        case .invalidSubsurfaceStacking(let error):
            error.description
        case .subsurfacePresentationFailed(let failure):
            failure.description
        case .presentationTimeUnavailable:
            "presentation-time protocol is unavailable"
        case .xdgToplevelIconUnavailable:
            "xdg-toplevel-icon protocol is unavailable"
        case .idleInhibitUnavailable:
            "idle-inhibit protocol is unavailable"
        case .systemBellUnavailable:
            "xdg-system-bell protocol is unavailable"
        case .unknownIdleInhibitor(let inhibitorID):
            "unknown idle inhibitor: \(inhibitorID)"
        case .foreignIdleInhibitor(let inhibitorID):
            "idle inhibitor belongs to another display: \(inhibitorID)"
        case .emptyWindowIconName:
            "window icon name must not be empty"
        case .windowIconNameContainsNUL:
            "window icon name must not contain NUL bytes"
        case .nonSquareWindowIconImage(let width, let height):
            "window icon image must be square, got \(width)x\(height)"
        case .invalidWindowIconImagePixelCount(let expected, let actual):
            "window icon image expected \(expected) pixels, got \(actual)"
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
        case .customImage:
            "set custom cursor image"
        case .animated:
            "set animated cursor"
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
