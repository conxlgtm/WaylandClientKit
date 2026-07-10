public enum DisplayOperationError: Error, Equatable, Sendable, CustomStringConvertible {
    case closed
    case unknownWindow(WindowID)
    case unknownPopup
    case unknownSubsurface(SubsurfaceIdentity)
    case closedPopup
    case closedSubsurface
    case foreignWindow(WindowID)
    case foreignSubsurface(SubsurfaceIdentity)
    case unknownSeat(SeatID)
    case invalidSubsurfaceStacking(SubsurfaceStackingError)
    case subsurfacePresentationFailed(SubsurfacePresentationFailure)
    case presentationTimeUnavailable
    case xdgToplevelIconUnavailable
    case xdgDialogUnavailable
    case xdgToplevelDragUnavailable
    case foreignToplevelListUnavailable
    case foreignToplevelListIncomplete
    case compositorSessionManagementUnavailable
    case invalidCompositorSessionID
    case outputManagementUnavailable
    case outputManagementIncomplete
    case foreignDragSource(DragSourceIdentity)
    case dragSourceSeatMismatch(DragSourceIdentity, expected: SeatID, actual: SeatID)
    case unknownToplevelDrag(ToplevelDragID)
    case foreignToplevelDrag(ToplevelDragID)
    case toplevelDragStillActive(ToplevelDragID)
    case idleInhibitUnavailable
    case keyboardShortcutsInhibitUnavailable
    case systemBellUnavailable
    case unknownIdleInhibitor(IdleInhibitorID)
    case foreignIdleInhibitor(IdleInhibitorID)
    case invalidDialogParent(child: WindowID, parent: WindowID)
    case dialogAlreadyExists(WindowID)
    case unknownWindowDialog(WindowDialogID)
    case foreignWindowDialog(WindowDialogID)
    case keyboardShortcutsAlreadyInhibited(window: WindowID, seat: SeatID)
    case unknownKeyboardShortcutsInhibitor(KeyboardShortcutsInhibitorID)
    case foreignKeyboardShortcutsInhibitor(KeyboardShortcutsInhibitorID)
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
        case .unknownSeat(let seatID):
            "unknown seat: \(seatID)"
        case .invalidSubsurfaceStacking(let error):
            error.description
        case .subsurfacePresentationFailed(let failure):
            failure.description
        case .presentationTimeUnavailable:
            "presentation-time protocol is unavailable"
        case .xdgToplevelIconUnavailable:
            "xdg-toplevel-icon protocol is unavailable"
        case .xdgDialogUnavailable:
            "xdg-dialog protocol is unavailable"
        case .xdgToplevelDragUnavailable:
            "xdg-toplevel-drag protocol is unavailable"
        case .foreignToplevelListUnavailable:
            "ext-foreign-toplevel-list protocol is unavailable"
        case .foreignToplevelListIncomplete:
            "ext-foreign-toplevel-list finished event was not observed"
        case .compositorSessionManagementUnavailable:
            "xdg-session-management protocol is unavailable"
        case .invalidCompositorSessionID:
            "compositor session ID must not be empty or contain NUL bytes"
        case .outputManagementUnavailable:
            "wlr-output-management protocol is unavailable"
        case .outputManagementIncomplete:
            "wlr-output-management done or finished lifecycle was incomplete"
        case .foreignDragSource(let sourceID):
            "drag source belongs to another display: \(sourceID)"
        case .dragSourceSeatMismatch(let sourceID, let expected, let actual):
            "drag source \(sourceID) is on seat \(actual), expected \(expected)"
        case .unknownToplevelDrag(let dragID):
            "unknown toplevel drag: \(dragID)"
        case .foreignToplevelDrag(let dragID):
            "toplevel drag belongs to another display: \(dragID)"
        case .toplevelDragStillActive(let dragID):
            "toplevel drag is still active: \(dragID)"
        case .idleInhibitUnavailable:
            "idle-inhibit protocol is unavailable"
        case .keyboardShortcutsInhibitUnavailable:
            "keyboard-shortcuts-inhibit protocol is unavailable"
        case .systemBellUnavailable:
            "xdg-system-bell protocol is unavailable"
        case .unknownIdleInhibitor(let inhibitorID):
            "unknown idle inhibitor: \(inhibitorID)"
        case .foreignIdleInhibitor(let inhibitorID):
            "idle inhibitor belongs to another display: \(inhibitorID)"
        case .invalidDialogParent(let child, let parent):
            "window \(child) cannot use \(parent) as its dialog parent"
        case .dialogAlreadyExists(let windowID):
            "window already has an xdg-dialog object: \(windowID)"
        case .unknownWindowDialog(let dialogID):
            "unknown window dialog: \(dialogID)"
        case .foreignWindowDialog(let dialogID):
            "window dialog belongs to another display: \(dialogID)"
        case .keyboardShortcutsAlreadyInhibited(let windowID, let seatID):
            "keyboard shortcuts are already inhibited for window \(windowID) on seat \(seatID)"
        case .unknownKeyboardShortcutsInhibitor(let inhibitorID):
            "unknown keyboard shortcuts inhibitor: \(inhibitorID)"
        case .foreignKeyboardShortcutsInhibitor(let inhibitorID):
            "keyboard shortcuts inhibitor belongs to another display: \(inhibitorID)"
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
