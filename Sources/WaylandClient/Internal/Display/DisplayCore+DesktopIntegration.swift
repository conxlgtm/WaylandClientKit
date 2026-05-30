import WaylandRaw

struct DisplayIdleInhibitorRecord {
    let id: IdleInhibitorID
    let windowID: WindowID
    let rawInhibitor: RawIdleInhibitor

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

    func removeAllIdleInhibitors() {
        let records = Array(idleInhibitorsByID.values)
        idleInhibitorsByID.removeAll(keepingCapacity: false)
        idleInhibitorIDsByWindowID.removeAll(keepingCapacity: false)
        closedIdleInhibitorIDs.formUnion(records.map(\.id))
        for record in records {
            record.destroy()
        }
    }
}
