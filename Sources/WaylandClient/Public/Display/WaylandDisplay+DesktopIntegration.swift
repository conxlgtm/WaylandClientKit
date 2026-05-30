extension WaylandDisplay {
    package func setWindowIcon(_ windowID: WindowID, _ icon: WindowIcon) throws {
        try requireCore().setWindowIcon(windowID, icon)
    }

    package func inhibitIdle(window: Window) throws -> IdleInhibitor {
        guard window.isOwned(by: self) else {
            throw ClientError.display(.foreignWindow(window.id))
        }

        let inhibitorID = try requireCore().createIdleInhibitor(windowID: window.id)
        return IdleInhibitor(id: inhibitorID, display: self)
    }

    package func destroyIdleInhibitor(_ inhibitorID: IdleInhibitorID) throws {
        try requireCore().destroyIdleInhibitor(inhibitorID)
    }

    public func ringSystemBell() throws {
        try requireCore().ringSystemBell(windowID: nil)
    }

    package func ringSystemBell(window: Window) throws {
        guard window.isOwned(by: self) else {
            throw ClientError.display(.foreignWindow(window.id))
        }

        try requireCore().ringSystemBell(windowID: window.id)
    }
}
