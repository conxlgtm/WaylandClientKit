extension RawInputDeviceID.Kind {
    package var sortRank: Int {
        switch self {
        case .pointer:
            0
        case .keyboard:
            1
        case .touch:
            2
        case .tablet:
            3
        }
    }
}

extension Sequence where Element == RawInputDeviceID {
    package func sortedByInputDeviceIdentity() -> [RawInputDeviceID] {
        sorted { lhs, rhs in
            (lhs.seatID.rawValue, lhs.kind.sortRank, lhs.generation)
                < (rhs.seatID.rawValue, rhs.kind.sortRank, rhs.generation)
        }
    }
}
