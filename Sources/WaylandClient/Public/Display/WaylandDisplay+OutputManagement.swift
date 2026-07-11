extension WaylandDisplay {
    public func outputManagementSnapshot(
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultDiscoveryTimeoutMilliseconds
    ) throws -> OutputManagementSnapshot {
        try requireCore().outputManagementSnapshot(
            timeoutMilliseconds: timeoutMilliseconds
        )
    }

    package func testCurrentOutputConfigurationForSmoke(
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultDiscoveryTimeoutMilliseconds
    ) throws {
        try requireCore().testCurrentOutputConfigurationForSmoke(
            timeoutMilliseconds: timeoutMilliseconds
        )
    }
}
