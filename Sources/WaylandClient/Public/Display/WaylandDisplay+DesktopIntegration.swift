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

    package func createDialog(
        child: Window,
        parent: Window,
        modal: Bool
    ) throws -> WindowDialog {
        guard child.isOwned(by: self) else {
            throw ClientError.display(.foreignWindow(child.id))
        }
        guard parent.isOwned(by: self) else {
            throw ClientError.display(.foreignWindow(parent.id))
        }

        let dialogID = try requireCore().createWindowDialog(
            childWindowID: child.id,
            parentWindowID: parent.id,
            modal: modal
        )
        return WindowDialog(
            id: dialogID,
            childWindowID: child.id,
            parentWindowID: parent.id,
            display: self
        )
    }

    package func setWindowDialogModal(_ dialogID: WindowDialogID, modal: Bool) throws {
        try requireCore().setWindowDialogModal(dialogID, modal: modal)
    }

    package func destroyWindowDialog(_ dialogID: WindowDialogID) throws {
        try requireCore().destroyWindowDialog(dialogID)
    }

    package func destroyIdleInhibitor(_ inhibitorID: IdleInhibitorID) throws {
        try requireCore().destroyIdleInhibitor(inhibitorID)
    }

    package func inhibitKeyboardShortcuts(
        window: Window,
        seatID: SeatID
    ) throws -> KeyboardShortcutsInhibitor {
        guard window.isOwned(by: self) else {
            throw ClientError.display(.foreignWindow(window.id))
        }

        let inhibitorID = try requireCore().createKeyboardShortcutsInhibitor(
            windowID: window.id,
            seatID: seatID
        )
        return KeyboardShortcutsInhibitor(
            id: inhibitorID,
            windowID: window.id,
            seatID: seatID,
            display: self
        )
    }

    package func destroyKeyboardShortcutsInhibitor(
        _ inhibitorID: KeyboardShortcutsInhibitorID
    ) throws {
        try requireCore().destroyKeyboardShortcutsInhibitor(inhibitorID)
    }

    public func foreignToplevelListSnapshot(
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultDiscoveryTimeoutMilliseconds
    ) throws -> ForeignToplevelListSnapshot {
        try requireCore().foreignToplevelListSnapshot(
            timeoutMilliseconds: timeoutMilliseconds
        )
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
