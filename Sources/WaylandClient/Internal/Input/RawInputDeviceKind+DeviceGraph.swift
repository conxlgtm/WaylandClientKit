import WaylandRaw

extension RawInputDeviceID.Kind {
    package static var inputDeviceKinds: [Self] {
        [.pointer, .keyboard, .touch]
    }
}

extension WaylandRaw.SeatCapabilities {
    package func containsDeviceKind(_ kind: RawInputDeviceID.Kind) -> Bool {
        switch kind {
        case .pointer:
            hasPointer
        case .keyboard:
            hasKeyboard
        case .touch:
            hasTouch
        }
    }
}
