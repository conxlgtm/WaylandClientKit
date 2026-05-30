extension WaylandDisplay {
    package func createSubsurface(
        parent window: Window,
        configuration subsurfaceConfiguration: SubsurfaceConfiguration
    ) throws -> Subsurface {
        guard window.isOwned(by: self) else {
            throw ClientError.display(.foreignWindow(window.id))
        }

        let subsurfaceID = try requireCore().createSubsurface(
            parent: window.id,
            configuration: subsurfaceConfiguration
        )
        return Subsurface(
            id: subsurfaceID,
            parentWindowID: window.id,
            display: self
        )
    }

    package func showSubsurface(
        _ subsurfaceID: SubsurfaceID,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().showSubsurface(subsurfaceID, damage: damage, draw)
    }

    package func redrawSubsurface(
        _ subsurfaceID: SubsurfaceID,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().redrawSubsurface(subsurfaceID, damage: damage, draw)
    }

    package func requestSubsurfaceRedraw(_ subsurfaceID: SubsurfaceID) throws {
        try requireCore().requestSubsurfaceRedraw(subsurfaceID)
    }

    package func setSubsurfaceInputRegion(
        _ subsurfaceID: SubsurfaceID,
        _ region: SurfaceRegion?
    ) throws {
        try requireCore().setSubsurfaceInputRegion(subsurfaceID, region)
    }

    package func setSubsurfaceOpaqueRegion(
        _ subsurfaceID: SubsurfaceID,
        _ region: SurfaceRegion?
    ) throws {
        try requireCore().setSubsurfaceOpaqueRegion(subsurfaceID, region)
    }

    package func setSubsurfacePosition(
        _ subsurfaceID: SubsurfaceID,
        _ position: LogicalOffset
    ) throws {
        try requireCore().setSubsurfacePosition(subsurfaceID, position)
    }

    package func placeSubsurface(
        _ subsurfaceID: SubsurfaceID,
        above siblingID: SubsurfaceID
    ) throws {
        try requireCore().placeSubsurface(subsurfaceID, above: siblingID)
    }

    package func placeSubsurface(
        _ subsurfaceID: SubsurfaceID,
        below siblingID: SubsurfaceID
    ) throws {
        try requireCore().placeSubsurface(subsurfaceID, below: siblingID)
    }

    package func setSubsurfaceSynchronized(_ subsurfaceID: SubsurfaceID) throws {
        try requireCore().setSubsurfaceSynchronized(subsurfaceID)
    }

    package func setSubsurfaceDesynchronized(_ subsurfaceID: SubsurfaceID) throws {
        try requireCore().setSubsurfaceDesynchronized(subsurfaceID)
    }

    package func subsurfaceIsClosed(_ subsurfaceID: SubsurfaceID) throws -> Bool {
        try requireCore().subsurfaceIsClosed(subsurfaceID)
    }

    package func subsurfaceNeedsRedraw(_ subsurfaceID: SubsurfaceID) throws -> Bool {
        try requireCore().subsurfaceNeedsRedraw(subsurfaceID)
    }

    package func subsurfaceGeometry(_ subsurfaceID: SubsurfaceID) throws -> SurfaceGeometry {
        try requireCore().subsurfaceGeometry(subsurfaceID)
    }
}
