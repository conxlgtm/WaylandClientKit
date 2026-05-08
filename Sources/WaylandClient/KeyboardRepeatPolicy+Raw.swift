import WaylandRaw

extension KeyboardRepeatPolicy {
    package init(_ rawRepeatInfo: WaylandRaw.RawKeyboardRepeatInfo) {
        switch rawRepeatInfo {
        case .disabled:
            self = .disabled
        case .enabled(let rawRate, let rawDelay):
            self = .enabled(
                rate: KeyboardRepeatRate(unchecked: rawRate.rawValue),
                delay: KeyboardRepeatDelay(unchecked: rawDelay.rawValue)
            )
        }
    }
}
