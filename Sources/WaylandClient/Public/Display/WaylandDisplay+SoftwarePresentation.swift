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
            draw
        )
    }

    package func showWindow(
        _ windowID: WindowID,
        timeoutMilliseconds: Int32,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().showWindow(
            windowID,
            timeoutMilliseconds: timeoutMilliseconds,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
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
            draw
        )
    }

    package func redraw(
        _ windowID: WindowID,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().redraw(
            windowID,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            draw
        )
    }
}
