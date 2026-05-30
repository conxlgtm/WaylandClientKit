extension DisplayCore {
    func createSubsurface(
        parent windowID: WindowID,
        configuration subsurfaceConfiguration: SubsurfaceConfiguration
    ) throws -> SubsurfaceID {
        try withFatalFailureFinalization {
            let parentWindow = try requireOpenWindow(windowID)
            let subsurface = try requireSession().createSubsurfaceOnOwnerThread(
                parent: parentWindow,
                configuration: subsurfaceConfiguration
            )
            guard !isClosed else {
                subsurface.closeOnOwnerThread()
                throw ClientError.display(.closed)
            }
            registerSubsurface(subsurface)
            parentWindow.commitSubsurfaceParentStateOnOwnerThread()
            return subsurface.id
        }
    }

    func showSubsurface(
        _ subsurfaceID: SubsurfaceID,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try withFatalFailureFinalization {
            let requirement = try requireOpenSubsurface(subsurfaceID).showOnOwnerThread(
                damage: damage,
                draw
            )
            try commitSubsurfaceParentStateIfNeeded(requirement)
            guard !isClosed, let activeSession else { return }
            publishSessionEvents(activeSession)
        }
    }

    func redrawSubsurface(
        _ subsurfaceID: SubsurfaceID,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try withFatalFailureFinalization {
            let requirement = try requireOpenSubsurface(subsurfaceID).redrawOnOwnerThread(
                damage: damage,
                draw
            )
            try commitSubsurfaceParentStateIfNeeded(requirement)
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
        }
    }

    func requestSubsurfaceRedraw(_ subsurfaceID: SubsurfaceID) throws {
        try withFatalFailureFinalization {
            try requireOpenSubsurface(subsurfaceID).requestRedrawOnOwnerThread()
        }
    }

    func setSubsurfaceInputRegion(
        _ subsurfaceID: SubsurfaceID,
        _ region: SurfaceRegion?
    ) throws {
        try withFatalFailureFinalization {
            let requirement = try requireOpenSubsurface(subsurfaceID)
                .setInputRegionOnOwnerThread(region)
            try commitSubsurfaceParentStateIfNeeded(requirement)
        }
    }

    func setSubsurfaceOpaqueRegion(
        _ subsurfaceID: SubsurfaceID,
        _ region: SurfaceRegion?
    ) throws {
        try withFatalFailureFinalization {
            let requirement = try requireOpenSubsurface(subsurfaceID)
                .setOpaqueRegionOnOwnerThread(region)
            try commitSubsurfaceParentStateIfNeeded(requirement)
        }
    }

    func setSubsurfacePosition(
        _ subsurfaceID: SubsurfaceID,
        _ position: LogicalOffset
    ) throws {
        try withFatalFailureFinalization {
            let requirement = try requireOpenSubsurface(subsurfaceID)
                .setPositionOnOwnerThread(position)
            try commitSubsurfaceParentStateIfNeeded(requirement)
        }
    }

    func placeSubsurface(
        _ subsurfaceID: SubsurfaceID,
        above siblingID: SubsurfaceID
    ) throws {
        try withFatalFailureFinalization {
            let subsurface = try requireOpenSubsurface(subsurfaceID)
            let sibling = try requireOpenSubsurface(siblingID)
            let requirement = try subsurface.placeAboveOnOwnerThread(sibling)
            try commitSubsurfaceParentStateIfNeeded(requirement)
        }
    }

    func placeSubsurface(
        _ subsurfaceID: SubsurfaceID,
        below siblingID: SubsurfaceID
    ) throws {
        try withFatalFailureFinalization {
            let subsurface = try requireOpenSubsurface(subsurfaceID)
            let sibling = try requireOpenSubsurface(siblingID)
            let requirement = try subsurface.placeBelowOnOwnerThread(sibling)
            try commitSubsurfaceParentStateIfNeeded(requirement)
        }
    }

    func setSubsurfaceSynchronized(_ subsurfaceID: SubsurfaceID) throws {
        try withFatalFailureFinalization {
            let requirement = try requireOpenSubsurface(subsurfaceID)
                .setSynchronizedOnOwnerThread()
            try commitSubsurfaceParentStateIfNeeded(requirement)
        }
    }

    func setSubsurfaceDesynchronized(_ subsurfaceID: SubsurfaceID) throws {
        try withFatalFailureFinalization {
            let requirement = try requireOpenSubsurface(subsurfaceID)
                .setDesynchronizedOnOwnerThread()
            try commitSubsurfaceParentStateIfNeeded(requirement)
        }
    }

    func closeSubsurface(_ subsurfaceID: SubsurfaceID) {
        withFatalFailureFinalization {
            guard !hasPendingFatalFailure else { return }
            guard let subsurface = subsurfacesByID.removeValue(forKey: subsurfaceID)
            else {
                return
            }
            subsurface.closeOnOwnerThread()
            closedSubsurfaceIDs.insert(subsurfaceID)
            let parentWindowID = subsurfaceParentWindowIDs.removeValue(forKey: subsurfaceID)
            if let parentWindowID {
                subsurfaceIDsByParentWindow[parentWindowID]?.removeAll { candidateID in
                    candidateID == subsurfaceID
                }
            }
        }
    }

    func subsurfaceIsClosed(_ subsurfaceID: SubsurfaceID) throws -> Bool {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
            if closedSubsurfaceIDs.contains(subsurfaceID) {
                return true
            }

            return try requireSubsurface(subsurfaceID).isClosedOnOwnerThread
        }
    }

    func subsurfaceNeedsRedraw(_ subsurfaceID: SubsurfaceID) throws -> Bool {
        try withFatalFailureFinalization {
            try requireOpenSubsurface(subsurfaceID).needsRedrawOnOwnerThread
        }
    }

    func subsurfaceGeometry(_ subsurfaceID: SubsurfaceID) throws -> SurfaceGeometry {
        try withFatalFailureFinalization {
            try requireOpenSubsurface(subsurfaceID).geometryOnOwnerThread
        }
    }

    func subsurfaceIDsTopDown(parentedBy windowID: WindowID) -> [SubsurfaceID] {
        (subsurfaceIDsByParentWindow[windowID] ?? []).reversed()
    }

    func removeAllSubsurfaces() {
        for subsurfaceID in Array(subsurfacesByID.keys) {
            closeSubsurface(subsurfaceID)
        }
        subsurfacesByID.removeAll(keepingCapacity: false)
        subsurfaceParentWindowIDs.removeAll(keepingCapacity: false)
        subsurfaceIDsByParentWindow.removeAll(keepingCapacity: false)
        closedSubsurfaceIDs.removeAll(keepingCapacity: false)
    }

    private func registerSubsurface(_ subsurface: SubsurfaceRoleSurface) {
        subsurfacesByID[subsurface.id] = subsurface
        subsurfaceParentWindowIDs[subsurface.id] = subsurface.parentWindowID
        subsurfaceIDsByParentWindow[subsurface.parentWindowID, default: []]
            .append(subsurface.id)
        closedSubsurfaceIDs.remove(subsurface.id)
    }

    private func commitSubsurfaceParentStateIfNeeded(
        _ requirement: SubsurfaceParentCommitRequirement?
    ) throws {
        guard let requirement else { return }
        try requireOpenWindow(requirement.parentWindowID)
            .commitSubsurfaceParentStateOnOwnerThread()
    }

    private func requireSubsurface(_ subsurfaceID: SubsurfaceID) throws
        -> SubsurfaceRoleSurface
    {
        guard let subsurface = subsurfacesByID[subsurfaceID] else {
            throw ClientError.display(.unknownSubsurface(SubsurfaceIdentity(subsurfaceID)))
        }

        return subsurface
    }

    private func requireOpenSubsurface(_ subsurfaceID: SubsurfaceID) throws
        -> SubsurfaceRoleSurface
    {
        guard !isClosed else {
            throw ClientError.display(.closed)
        }
        guard !closedSubsurfaceIDs.contains(subsurfaceID) else {
            throw ClientError.display(.closedSubsurface)
        }
        let subsurface = try requireSubsurface(subsurfaceID)
        guard !subsurface.isClosedOnOwnerThread else {
            throw ClientError.display(.closedSubsurface)
        }

        return subsurface
    }
}
