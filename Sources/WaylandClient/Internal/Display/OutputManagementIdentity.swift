struct OutputManagementModeStableKey: Hashable {
    let headID: OutputManagementHeadID
    let width: Int32
    let height: Int32
    let refreshMilliHertz: Int32

    init?(headID outputHeadID: OutputManagementHeadID, mode: OutputManagementCollector.ModeState) {
        guard let size = mode.size else { return nil }

        headID = outputHeadID
        width = size.width.rawValue
        height = size.height.rawValue
        refreshMilliHertz = mode.refresh.identityMilliHertz
    }
}

extension OutputRefreshRate {
    var identityMilliHertz: Int32 {
        switch self {
        case .unspecified:
            0
        case .milliHertz(let value):
            value.rawValue
        }
    }
}
