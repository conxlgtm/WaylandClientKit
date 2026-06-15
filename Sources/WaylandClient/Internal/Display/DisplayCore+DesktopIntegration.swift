import WaylandRaw

struct DisplayIdleInhibitorRecord {
    let id: IdleInhibitorID
    let windowID: WindowID
    let rawInhibitor: RawIdleInhibitor

    func destroy() {
        rawInhibitor.destroy()
    }
}

struct DisplayWindowDialogRecord {
    let id: WindowDialogID
    let childWindowID: WindowID
    let parentWindowID: WindowID
    let rawDialog: RawXDGDialog

    func destroy() {
        rawDialog.destroy()
    }
}

struct DisplayKeyboardShortcutsInhibitorRecord {
    let id: KeyboardShortcutsInhibitorID
    let windowID: WindowID
    let seatID: SeatID
    let rawInhibitor: RawKeyboardShortcutsInhibitor

    func destroy() {
        rawInhibitor.destroy()
    }
}

extension DisplayCore {
    func setWindowIcon(_ windowID: WindowID, _ icon: WindowIcon) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).setIconOnOwnerThread(icon)
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
        }
    }

    func createIdleInhibitor(windowID: WindowID) throws -> IdleInhibitorID {
        try withFatalFailureFinalization {
            let window = try requireOpenWindow(windowID)
            let session = try requireSession()
            guard let manager = try session.connection.bindIdleInhibitManagerOneShot() else {
                throw ClientError.display(.idleInhibitUnavailable)
            }
            defer { manager.destroy() }

            let inhibitorID = idleInhibitorIDs.next()
            let inhibitor = try manager.createInhibitor(surface: window.rawSurfaceOnOwnerThread)
            let record = DisplayIdleInhibitorRecord(
                id: inhibitorID,
                windowID: windowID,
                rawInhibitor: inhibitor
            )
            idleInhibitorsByID[inhibitorID] = record
            idleInhibitorIDsByWindowID[windowID, default: []].append(inhibitorID)
            closedIdleInhibitorIDs.remove(inhibitorID)
            return inhibitorID
        }
    }

    func createWindowDialog(
        childWindowID: WindowID,
        parentWindowID: WindowID,
        modal: Bool
    ) throws -> WindowDialogID {
        try withFatalFailureFinalization {
            let child = try requireOpenWindow(childWindowID)
            let parent = try requireOpenWindow(parentWindowID)
            try validateDialogParent(childWindowID: childWindowID, parentWindowID: parentWindowID)
            guard windowDialogIDByChildWindowID[childWindowID] == nil else {
                throw ClientError.display(.dialogAlreadyExists(childWindowID))
            }

            let session = try requireSession()
            guard let manager = try session.connection.bindXDGDialogManagerOneShot() else {
                throw ClientError.display(.xdgDialogUnavailable)
            }
            defer { manager.destroy() }

            let dialogID = windowDialogIDs.next()
            let dialog = try child.createDialogOnOwnerThread(
                parent: parent,
                manager: manager,
                modal: modal
            )
            let record = DisplayWindowDialogRecord(
                id: dialogID,
                childWindowID: childWindowID,
                parentWindowID: parentWindowID,
                rawDialog: dialog
            )
            windowDialogsByID[dialogID] = record
            windowDialogIDByChildWindowID[childWindowID] = dialogID
            windowDialogIDsByParentWindowID[parentWindowID, default: []].append(dialogID)
            closedWindowDialogIDs.remove(dialogID)
            return dialogID
        }
    }

    func setWindowDialogModal(_ dialogID: WindowDialogID, modal: Bool) throws {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
            guard let record = windowDialogsByID[dialogID] else {
                throw ClientError.display(.unknownWindowDialog(dialogID))
            }

            if modal {
                record.rawDialog.setModal()
            } else {
                record.rawDialog.unsetModal()
            }
        }
    }

    func destroyWindowDialog(_ dialogID: WindowDialogID) throws {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
            guard windowDialogsByID[dialogID] != nil else {
                if closedWindowDialogIDs.contains(dialogID) {
                    return
                }

                throw ClientError.display(.unknownWindowDialog(dialogID))
            }

            closeWindowDialog(dialogID)
        }
    }

    func createKeyboardShortcutsInhibitor(
        windowID: WindowID,
        seatID: SeatID
    ) throws -> KeyboardShortcutsInhibitorID {
        try withFatalFailureFinalization {
            let window = try requireOpenWindow(windowID)
            let session = try requireSession()
            try validateKeyboardShortcutsInhibitorIsNew(windowID: windowID, seatID: seatID)
            let seat = try session.rawSeatOnOwnerThread(seatID: seatID)
            guard let manager = try session.connection.bindKeyboardShortcutsInhibitManagerOneShot()
            else {
                throw ClientError.display(.keyboardShortcutsInhibitUnavailable)
            }
            defer { manager.destroy() }

            let inhibitorID = keyboardShortcutsInhibitorIDs.next()
            let inhibitor = try manager.inhibitShortcuts(
                surface: window.rawSurfaceOnOwnerThread,
                seat: seat
            )
            let record = DisplayKeyboardShortcutsInhibitorRecord(
                id: inhibitorID,
                windowID: windowID,
                seatID: seatID,
                rawInhibitor: inhibitor
            )
            keyboardShortcutsInhibitorsByID[inhibitorID] = record
            keyboardShortcutsInhibitorIDsByWindowID[windowID, default: []]
                .append(inhibitorID)
            keyboardShortcutsInhibitorIDsBySeatID[seatID, default: []].append(inhibitorID)
            closedKeyboardShortcutsInhibitorIDs.remove(inhibitorID)
            return inhibitorID
        }
    }

    func destroyKeyboardShortcutsInhibitor(
        _ inhibitorID: KeyboardShortcutsInhibitorID
    ) throws {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
            guard keyboardShortcutsInhibitorsByID[inhibitorID] != nil else {
                if closedKeyboardShortcutsInhibitorIDs.contains(inhibitorID) {
                    return
                }

                throw ClientError.display(.unknownKeyboardShortcutsInhibitor(inhibitorID))
            }

            closeKeyboardShortcutsInhibitor(inhibitorID)
        }
    }

    func destroyIdleInhibitor(_ inhibitorID: IdleInhibitorID) throws {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
            guard idleInhibitorsByID[inhibitorID] != nil else {
                if closedIdleInhibitorIDs.contains(inhibitorID) {
                    return
                }

                throw ClientError.display(.unknownIdleInhibitor(inhibitorID))
            }

            closeIdleInhibitor(inhibitorID)
        }
    }

    func ringSystemBell(windowID: WindowID?) throws {
        try withFatalFailureFinalization {
            let surface: RawSurface?
            if let windowID {
                surface = try requireOpenWindow(windowID).rawSurfaceOnOwnerThread
            } else {
                surface = nil
            }
            let session = try requireSession()
            guard let bell = try session.connection.bindSystemBellOneShot() else {
                throw ClientError.display(.systemBellUnavailable)
            }
            defer { bell.destroy() }

            bell.ring(surface: surface)
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
        }
    }

    func closeIdleInhibitor(_ inhibitorID: IdleInhibitorID) {
        guard let record = idleInhibitorsByID.removeValue(forKey: inhibitorID) else {
            return
        }

        record.destroy()
        if var windowInhibitors = idleInhibitorIDsByWindowID[record.windowID] {
            windowInhibitors.removeAll { $0 == inhibitorID }
            if windowInhibitors.isEmpty {
                idleInhibitorIDsByWindowID.removeValue(forKey: record.windowID)
            } else {
                idleInhibitorIDsByWindowID[record.windowID] = windowInhibitors
            }
        }
        closedIdleInhibitorIDs.insert(inhibitorID)
    }

    func closeWindowDialogs(forClosingWindow windowID: WindowID) {
        if let dialogID = windowDialogIDByChildWindowID[windowID] {
            closeWindowDialog(dialogID)
        }
        for dialogID in windowDialogIDsByParentWindowID[windowID] ?? [] {
            closeWindowDialog(dialogID)
        }
    }

    func closeWindowDialog(_ dialogID: WindowDialogID) {
        guard let record = windowDialogsByID.removeValue(forKey: dialogID) else {
            return
        }

        if let childWindow = surfaces.window(record.childWindowID),
            !childWindow.isClosedOnOwnerThread
        {
            try? childWindow.clearDialogParentOnOwnerThread()
        }
        record.destroy()
        windowDialogIDByChildWindowID.removeValue(forKey: record.childWindowID)
        if var parentDialogs = windowDialogIDsByParentWindowID[record.parentWindowID] {
            parentDialogs.removeAll { $0 == dialogID }
            if parentDialogs.isEmpty {
                windowDialogIDsByParentWindowID.removeValue(forKey: record.parentWindowID)
            } else {
                windowDialogIDsByParentWindowID[record.parentWindowID] = parentDialogs
            }
        }
        closedWindowDialogIDs.insert(dialogID)
    }

    func closeKeyboardShortcutsInhibitor(_ inhibitorID: KeyboardShortcutsInhibitorID) {
        guard let record = keyboardShortcutsInhibitorsByID.removeValue(forKey: inhibitorID)
        else {
            return
        }

        record.destroy()
        if var windowInhibitors =
            keyboardShortcutsInhibitorIDsByWindowID[record.windowID]
        {
            windowInhibitors.removeAll { $0 == inhibitorID }
            if windowInhibitors.isEmpty {
                keyboardShortcutsInhibitorIDsByWindowID.removeValue(forKey: record.windowID)
            } else {
                keyboardShortcutsInhibitorIDsByWindowID[record.windowID] = windowInhibitors
            }
        }
        if var seatInhibitors = keyboardShortcutsInhibitorIDsBySeatID[record.seatID] {
            seatInhibitors.removeAll { $0 == inhibitorID }
            if seatInhibitors.isEmpty {
                keyboardShortcutsInhibitorIDsBySeatID.removeValue(forKey: record.seatID)
            } else {
                keyboardShortcutsInhibitorIDsBySeatID[record.seatID] = seatInhibitors
            }
        }
        closedKeyboardShortcutsInhibitorIDs.insert(inhibitorID)
    }

    func removeAllIdleInhibitors() {
        let records = Array(idleInhibitorsByID.values)
        idleInhibitorsByID.removeAll(keepingCapacity: false)
        idleInhibitorIDsByWindowID.removeAll(keepingCapacity: false)
        closedIdleInhibitorIDs.formUnion(records.map(\.id))
        for record in records {
            record.destroy()
        }
    }

    func removeAllWindowDialogs() {
        let records = Array(windowDialogsByID.values)
        windowDialogsByID.removeAll(keepingCapacity: false)
        windowDialogIDByChildWindowID.removeAll(keepingCapacity: false)
        windowDialogIDsByParentWindowID.removeAll(keepingCapacity: false)
        closedWindowDialogIDs.formUnion(records.map(\.id))
        for record in records {
            record.destroy()
        }
    }

    func removeAllKeyboardShortcutsInhibitors() {
        let records = Array(keyboardShortcutsInhibitorsByID.values)
        keyboardShortcutsInhibitorsByID.removeAll(keepingCapacity: false)
        keyboardShortcutsInhibitorIDsByWindowID.removeAll(keepingCapacity: false)
        keyboardShortcutsInhibitorIDsBySeatID.removeAll(keepingCapacity: false)
        closedKeyboardShortcutsInhibitorIDs.formUnion(records.map(\.id))
        for record in records {
            record.destroy()
        }
    }

    private func validateDialogParent(
        childWindowID: WindowID,
        parentWindowID: WindowID
    ) throws {
        guard childWindowID != parentWindowID,
            !dialogWindow(parentWindowID, isDescendantOf: childWindowID)
        else {
            throw ClientError.display(
                .invalidDialogParent(child: childWindowID, parent: parentWindowID)
            )
        }
    }

    private func dialogWindow(_ windowID: WindowID, isDescendantOf ancestorID: WindowID) -> Bool {
        var currentID = windowID
        var visited: Set<WindowID> = []
        while visited.insert(currentID).inserted,
            let dialogID = windowDialogIDByChildWindowID[currentID],
            let record = windowDialogsByID[dialogID]
        {
            if record.parentWindowID == ancestorID {
                return true
            }
            currentID = record.parentWindowID
        }

        return false
    }

    private func validateKeyboardShortcutsInhibitorIsNew(
        windowID: WindowID,
        seatID: SeatID
    ) throws {
        let duplicate = keyboardShortcutsInhibitorsByID.values.contains { record in
            record.windowID == windowID && record.seatID == seatID
        }
        guard !duplicate else {
            throw ClientError.display(
                .keyboardShortcutsAlreadyInhibited(window: windowID, seat: seatID)
            )
        }
    }
}

extension DisplaySession {
    package func rawSeatOnOwnerThread(seatID: SeatID) throws -> RawSeat {
        connection.preconditionIsOwnerThread()
        let globals = try connection.bindRequiredGlobals()
        guard let seat = globals.seatRegistry.seat(for: RawSeatID(seatID)) else {
            throw ClientError.display(.unknownSeat(seatID))
        }

        return seat
    }
}
