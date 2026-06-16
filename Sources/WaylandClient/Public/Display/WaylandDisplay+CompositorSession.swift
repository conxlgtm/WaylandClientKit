extension WaylandDisplay {
    public func compositorSessionEvents(
        reason: CompositorSessionReason = .launch,
        existingID: CompositorSessionID? = nil,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultDiscoveryTimeoutMilliseconds
    ) throws -> CompositorSessionEventSnapshot {
        try requireCore().compositorSessionEvents(
            reason: reason,
            existingID: existingID,
            timeoutMilliseconds: timeoutMilliseconds
        )
    }
}
