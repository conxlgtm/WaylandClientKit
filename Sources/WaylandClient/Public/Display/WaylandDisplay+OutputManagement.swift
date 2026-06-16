extension WaylandDisplay {
    public func outputManagementSnapshot(
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultDiscoveryTimeoutMilliseconds
    ) throws -> OutputManagementSnapshot {
        try requireCore().outputManagementSnapshot(
            timeoutMilliseconds: timeoutMilliseconds
        )
    }

    public func testOutputConfiguration(
        _ proposal: OutputConfigurationProposal,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultDiscoveryTimeoutMilliseconds
    ) throws {
        try requireCore().testOutputConfiguration(
            proposal,
            timeoutMilliseconds: timeoutMilliseconds
        )
    }

    public func applyOutputConfiguration(
        _ proposal: OutputConfigurationProposal,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultDiscoveryTimeoutMilliseconds
    ) throws {
        try requireCore().applyOutputConfiguration(
            proposal,
            timeoutMilliseconds: timeoutMilliseconds
        )
    }
}
