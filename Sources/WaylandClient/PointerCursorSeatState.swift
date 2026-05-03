import WaylandRaw

package enum PointerFocusState: Equatable, Sendable {
    case unfocused
    case focused(surfaceID: RawObjectID, enterSerial: UInt32)

    var enterSerial: UInt32? {
        switch self {
        case .unfocused:
            nil
        case .focused(_, let serial):
            serial
        }
    }

    var isFocused: Bool {
        enterSerial != nil
    }

    func isFocused(on surfaceID: RawObjectID?) -> Bool {
        guard case .focused(let focusedSurfaceID, _) = self else {
            return false
        }

        return focusedSurfaceID == surfaceID
    }
}

package enum PointerCursorSeatEvent: Equatable, Sendable {
    case managedPointerEntered(surfaceID: RawObjectID, serial: UInt32, sourceEvent: RawInputEvent)
    case unmanagedPointerEntered
    case pointerLeft(surfaceID: RawObjectID?)
    case registeredSurfaceRemoved(RawObjectID)
    case pointerUnavailable
}

package enum PointerCursorSeatEffect {
    case applyCursor(serial: UInt32, sourceEvent: RawInputEvent)
    case destroyCursorSurface(CursorManagerSurface)
}

package enum PointerCursorApplicationState: Equatable, Sendable {
    case unapplied
    case hidden(serial: UInt32)
    case named(cursor: PointerCursor, serial: UInt32, surfaceID: RawObjectID?)
}

package struct PointerCursorSeatState {
    var focus: PointerFocusState = .unfocused
    var cursorSurface: CursorManagerSurface?
    var application: PointerCursorApplicationState = .unapplied

    var isEmpty: Bool {
        !focus.isFocused && cursorSurface == nil && application == .unapplied
    }

    mutating func reduce(_ event: PointerCursorSeatEvent) -> [PointerCursorSeatEffect] {
        switch event {
        case .managedPointerEntered(let surfaceID, let serial, let sourceEvent):
            focus = .focused(surfaceID: surfaceID, enterSerial: serial)
            application = .unapplied
            return [.applyCursor(serial: serial, sourceEvent: sourceEvent)]
        case .unmanagedPointerEntered:
            focus = .unfocused
            application = .unapplied
            return []
        case .pointerLeft(let surfaceID):
            if focus.isFocused(on: surfaceID) {
                focus = .unfocused
                application = .unapplied
            }
            return []
        case .registeredSurfaceRemoved(let surfaceID):
            if focus.isFocused(on: surfaceID) {
                focus = .unfocused
                application = .unapplied
            }
            return []
        case .pointerUnavailable:
            focus = .unfocused
            application = .unapplied
            guard let surface = cursorSurface else {
                return []
            }

            cursorSurface = nil
            return [.destroyCursorSurface(surface)]
        }
    }

    mutating func markApplied(_ appliedCursor: PointerCursorApplicationState) {
        application = appliedCursor
    }
}
