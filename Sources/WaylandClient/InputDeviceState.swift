import WaylandRaw

enum InputDeviceIdentity: Equatable {
    case anonymous
    case identified(RawInputDeviceID)

    var currentID: RawInputDeviceID? {
        guard case .identified(let deviceID) = self else {
            return nil
        }

        return deviceID
    }
}

enum PointerDeviceState: Equatable {
    case absent
    case present(identity: InputDeviceIdentity, focusedSurfaceID: RawObjectID?)

    var isPresent: Bool {
        guard case .present = self else {
            return false
        }

        return true
    }

    var currentID: RawInputDeviceID? {
        guard case .present(let identity, _) = self else {
            return nil
        }

        return identity.currentID
    }

    var focusedSurfaceID: RawObjectID? {
        guard case .present(_, let surfaceID) = self else {
            return nil
        }

        return surfaceID
    }

    mutating func setFocus(_ surfaceID: RawObjectID) {
        switch self {
        case .absent:
            self = .present(identity: .anonymous, focusedSurfaceID: surfaceID)
        case .present(let identity, _):
            self = .present(identity: identity, focusedSurfaceID: surfaceID)
        }
    }

    mutating func clearFocus(matching surfaceID: RawObjectID) {
        guard case .present(let identity, let focusedSurfaceID) = self,
            focusedSurfaceID == surfaceID
        else {
            return
        }

        self = .present(identity: identity, focusedSurfaceID: nil)
    }
}

enum KeyboardDeviceState: Equatable {
    case absent
    case present(identity: InputDeviceIdentity, focusedSurfaceID: RawObjectID?)

    var isPresent: Bool {
        guard case .present = self else {
            return false
        }

        return true
    }

    var currentID: RawInputDeviceID? {
        guard case .present(let identity, _) = self else {
            return nil
        }

        return identity.currentID
    }

    var focusedSurfaceID: RawObjectID? {
        guard case .present(_, let surfaceID) = self else {
            return nil
        }

        return surfaceID
    }

    mutating func setFocus(_ surfaceID: RawObjectID) {
        switch self {
        case .absent:
            self = .present(identity: .anonymous, focusedSurfaceID: surfaceID)
        case .present(let identity, _):
            self = .present(identity: identity, focusedSurfaceID: surfaceID)
        }
    }

    mutating func clearFocus(matching surfaceID: RawObjectID) {
        guard case .present(let identity, let focusedSurfaceID) = self,
            focusedSurfaceID == surfaceID
        else {
            return
        }

        self = .present(identity: identity, focusedSurfaceID: nil)
    }
}

enum TouchDeviceState: Equatable {
    case absent
    case present(
        identity: InputDeviceIdentity,
        focusedSurfaceByTouchID: [Int32: RawObjectID]
    )

    var isPresent: Bool {
        guard case .present = self else {
            return false
        }

        return true
    }

    var currentID: RawInputDeviceID? {
        guard case .present(let identity, _) = self else {
            return nil
        }

        return identity.currentID
    }

    func focus(touchID: Int32) -> RawObjectID? {
        guard case .present(_, let focusedSurfaceByTouchID) = self else {
            return nil
        }

        return focusedSurfaceByTouchID[touchID]
    }

    mutating func setFocus(touchID: Int32, surfaceID: RawObjectID) {
        switch self {
        case .absent:
            self = .present(
                identity: .anonymous,
                focusedSurfaceByTouchID: [touchID: surfaceID]
            )
        case .present(let identity, var focusedSurfaceByTouchID):
            focusedSurfaceByTouchID[touchID] = surfaceID
            self = .present(
                identity: identity,
                focusedSurfaceByTouchID: focusedSurfaceByTouchID
            )
        }
    }

    mutating func clearFocus(touchID: Int32) {
        guard case .present(let identity, var focusedSurfaceByTouchID) = self else {
            return
        }

        focusedSurfaceByTouchID[touchID] = nil
        self = .present(
            identity: identity,
            focusedSurfaceByTouchID: focusedSurfaceByTouchID
        )
    }

    mutating func clearFocuses() {
        guard case .present(let identity, _) = self else {
            return
        }

        self = .present(identity: identity, focusedSurfaceByTouchID: [:])
    }

    mutating func removeFocuses(matching surfaceID: RawObjectID) {
        guard case .present(let identity, let focusedSurfaceByTouchID) = self else {
            return
        }

        let remainingFocuses = focusedSurfaceByTouchID.filter { entry in
            entry.value != surfaceID
        }
        self = .present(
            identity: identity,
            focusedSurfaceByTouchID: remainingFocuses
        )
    }
}
