public struct WindowStateSnapshot: Equatable, Sendable {
    public let configureSerial: UInt32
    public let size: PositiveLogicalSize
    public let states: [WindowStateToken]
    public let bounds: PositiveLogicalSize?
    public let managerCapabilities: [WindowManagerCapability]
    public let decorationMode: WindowDecorationMode?

    public init(
        configureSerial snapshotConfigureSerial: UInt32,
        size snapshotSize: PositiveLogicalSize,
        states snapshotStates: [WindowStateToken],
        bounds snapshotBounds: PositiveLogicalSize?,
        managerCapabilities snapshotManagerCapabilities: [WindowManagerCapability],
        decorationMode snapshotDecorationMode: WindowDecorationMode?
    ) {
        configureSerial = snapshotConfigureSerial
        size = snapshotSize
        states = snapshotStates
        bounds = snapshotBounds
        managerCapabilities = snapshotManagerCapabilities
        decorationMode = snapshotDecorationMode
    }

    package init(_ configuration: ResolvedWindowConfiguration) {
        self.init(
            configureSerial: configuration.serial,
            size: configuration.size,
            states: configuration.states,
            bounds: configuration.bounds,
            managerCapabilities: configuration.wmCapabilities,
            decorationMode: configuration.decorationMode
        )
    }
}
