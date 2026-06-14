import WaylandRaw

package enum PointerCursorApplicationState: Equatable, Sendable {
    case unapplied
    case hidden(serial: UInt32)
    case named(cursor: PointerCursor, serial: UInt32, surfaceID: RawObjectID?)
    case customImage(cursor: PointerCursor, serial: UInt32, surfaceID: RawObjectID?)
    case animated(cursor: PointerCursor, serial: UInt32, surfaceID: RawObjectID?, frameIndex: Int)
}

package enum PointerFocusState: Equatable, Sendable {
    case unfocused
    case focused(
        surfaceID: RawObjectID,
        enterSerial: UInt32,
        application: PointerCursorApplicationState
    )

    var enterSerial: UInt32? {
        switch self {
        case .unfocused:
            nil
        case .focused(_, let serial, _):
            serial
        }
    }

    var surfaceID: RawObjectID? {
        switch self {
        case .unfocused:
            nil
        case .focused(let surfaceID, _, _):
            surfaceID
        }
    }

    var isFocused: Bool {
        enterSerial != nil
    }

    var application: PointerCursorApplicationState {
        switch self {
        case .unfocused:
            .unapplied
        case .focused(_, _, let application):
            application
        }
    }

    func isFocused(on surfaceID: RawObjectID?) -> Bool {
        guard case .focused(let focusedSurfaceID, _, _) = self else {
            return false
        }

        return focusedSurfaceID == surfaceID
    }

    mutating func markApplied(_ application: PointerCursorApplicationState) {
        guard case .focused(let surfaceID, let serial, _) = self else {
            return
        }

        self = .focused(
            surfaceID: surfaceID,
            enterSerial: serial,
            application: application
        )
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

package struct PointerCursorSeatState {
    var focus: PointerFocusState = .unfocused
    var cursorSurface: CursorManagerSurface?
    var animation: CursorAnimationState?

    var application: PointerCursorApplicationState {
        focus.application
    }

    var isEmpty: Bool {
        !focus.isFocused && cursorSurface == nil
    }

    mutating func reduce(_ event: PointerCursorSeatEvent) -> [PointerCursorSeatEffect] {
        switch event {
        case .managedPointerEntered(let surfaceID, let serial, let sourceEvent):
            focus = .focused(
                surfaceID: surfaceID,
                enterSerial: serial,
                application: .unapplied
            )
            return [.applyCursor(serial: serial, sourceEvent: sourceEvent)]
        case .unmanagedPointerEntered:
            focus = .unfocused
            animation = nil
            return []
        case .pointerLeft(let surfaceID):
            if focus.isFocused(on: surfaceID) {
                focus = .unfocused
                animation = nil
            }
            return []
        case .registeredSurfaceRemoved(let surfaceID):
            if focus.isFocused(on: surfaceID) {
                focus = .unfocused
                animation = nil
            }
            return []
        case .pointerUnavailable:
            focus = .unfocused
            animation = nil
            guard let surface = cursorSurface else {
                return []
            }

            cursorSurface = nil
            return [.destroyCursorSurface(surface)]
        }
    }

    mutating func markApplied(_ appliedCursor: PointerCursorApplicationState) {
        focus.markApplied(appliedCursor)
    }
}
