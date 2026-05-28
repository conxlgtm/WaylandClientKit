import WaylandRaw

extension SeatID {
    package init(_ raw: RawSeatID) {
        self.init(rawValue: raw.rawValue)
    }
}

extension RawSeatID {
    package init(_ seatID: SeatID) {
        self.init(rawValue: seatID.rawValue)
    }
}

extension OutputID {
    package init(_ raw: RawOutputID) {
        self.init(rawValue: raw.rawValue)
    }
}

extension RawOutputID {
    package init(_ outputID: OutputID) {
        self.init(rawValue: outputID.rawValue)
    }
}

extension ButtonState {
    package init(_ raw: RawPointerButtonState) {
        self.init(rawValue: raw.rawValue)
    }
}

extension KeyState {
    package init(_ raw: RawKeyboardKeyState) {
        self.init(rawValue: raw.rawValue)
    }
}

extension KeyboardKeymapFormat {
    package init(_ raw: RawKeyboardKeymapFormat) {
        self.init(rawValue: raw.rawValue)
    }
}

extension PointerAxis {
    package init(_ raw: RawPointerAxis) {
        self.init(rawValue: raw.rawValue)
    }
}

extension PointerAxisSource {
    package init(_ raw: RawPointerAxisSource) {
        self.init(rawValue: raw.rawValue)
    }
}

extension PointerAxisRelativeDirection {
    package init(_ raw: RawPointerAxisRelativeDirection) {
        self.init(rawValue: raw.rawValue)
    }
}

extension PointerConstraintKind {
    package init(_ raw: RawPointerConstraintKind) {
        switch raw {
        case .locked:
            self = .locked
        case .confined:
            self = .confined
        }
    }
}
