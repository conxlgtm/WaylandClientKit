public struct WindowStateSnapshot: Equatable, Sendable {
    public let title: String?
    public let appID: String?
    public let configureSerial: UInt32
    public let size: PositiveLogicalSize
    public let states: [WindowStateToken]
    public let bounds: PositiveLogicalSize?
    public let managerCapabilities: [WindowManagerCapability]
    public let decorationMode: WindowDecorationMode?
    public let outputs: [OutputID]

    public init(
        configureSerial snapshotConfigureSerial: UInt32,
        size snapshotSize: PositiveLogicalSize,
        states snapshotStates: [WindowStateToken],
        bounds snapshotBounds: PositiveLogicalSize?,
        managerCapabilities snapshotManagerCapabilities: [WindowManagerCapability],
        decorationMode snapshotDecorationMode: WindowDecorationMode?,
        outputs snapshotOutputs: [OutputID] = [],
        title snapshotTitle: String? = nil,
        appID snapshotAppID: String? = nil
    ) {
        title = snapshotTitle
        appID = snapshotAppID
        configureSerial = snapshotConfigureSerial
        size = snapshotSize
        states = snapshotStates
        bounds = snapshotBounds
        managerCapabilities = snapshotManagerCapabilities
        decorationMode = snapshotDecorationMode
        outputs = snapshotOutputs
    }

    package init(
        _ configuration: ResolvedWindowConfiguration,
        outputIDs snapshotOutputs: [OutputID] = [],
        title snapshotTitle: String? = nil,
        appID snapshotAppID: String? = nil
    ) {
        self.init(
            configureSerial: configuration.serial,
            size: configuration.size,
            states: configuration.states,
            bounds: configuration.bounds,
            managerCapabilities: configuration.wmCapabilities,
            decorationMode: configuration.decorationMode,
            outputs: snapshotOutputs,
            title: snapshotTitle,
            appID: snapshotAppID
        )
    }
}
