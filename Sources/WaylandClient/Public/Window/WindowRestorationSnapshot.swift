public struct WindowRestorationSnapshot: Equatable, Sendable {
    public let windowID: WindowID
    public let title: String?
    public let appID: String?
    public let geometry: SurfaceGeometry
    public let state: WindowStateSnapshot
    public let decorationMode: WindowDecorationMode
    public let outputs: [OutputID]

    public init(
        windowID snapshotWindowID: WindowID,
        title snapshotTitle: String?,
        appID snapshotAppID: String?,
        geometry snapshotGeometry: SurfaceGeometry,
        state snapshotState: WindowStateSnapshot,
        decorationMode snapshotDecorationMode: WindowDecorationMode,
        outputs snapshotOutputs: [OutputID] = []
    ) {
        windowID = snapshotWindowID
        title = snapshotTitle
        appID = snapshotAppID
        geometry = snapshotGeometry
        state = snapshotState
        decorationMode = snapshotDecorationMode
        outputs = snapshotOutputs
    }
}
