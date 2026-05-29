extension WaylandDisplay {
    package func showWindow(
        _ windowID: WindowID,
        timeoutMilliseconds: Int32 = defaultConfigureTimeoutMilliseconds,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try showWindow(
            windowID,
            timeoutMilliseconds: timeoutMilliseconds,
            metadata: .default,
            requestPresentationFeedback: false,
            damage: nil,
            draw
        )
    }

    package func showWindow(
        _ windowID: WindowID,
        timeoutMilliseconds: Int32,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion? = nil,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().showWindow(
            windowID,
            timeoutMilliseconds: timeoutMilliseconds,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            damage: damage,
            draw
        )
    }

    package func redraw(
        _ windowID: WindowID,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try redraw(
            windowID,
            metadata: .default,
            requestPresentationFeedback: false,
            damage: nil,
            draw
        )
    }

    package func redraw(
        _ windowID: WindowID,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion? = nil,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().redraw(
            windowID,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            damage: damage,
            draw
        )
    }
}
