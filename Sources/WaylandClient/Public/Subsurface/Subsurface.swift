public struct Subsurface: Sendable, Hashable, Identifiable {
    package let subsurfaceID: SubsurfaceID
    public let id: SubsurfaceIdentity
    public let parentWindowID: WindowID

    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<SubsurfaceID>

    package init(
        id managedSubsurfaceID: SubsurfaceID,
        parentWindowID subsurfaceParentWindowID: WindowID,
        display owningDisplay: WaylandDisplay
    ) {
        subsurfaceID = managedSubsurfaceID
        id = SubsurfaceIdentity(managedSubsurfaceID)
        parentWindowID = subsurfaceParentWindowID
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: managedSubsurfaceID, display: owningDisplay)
    }

    public var identity: SubsurfaceIdentity {
        id
    }

    package func isOwned(by owningDisplay: WaylandDisplay) -> Bool {
        ownership.isOwned(by: owningDisplay)
    }

    public func show(
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.showSubsurface(subsurfaceID, damage: nil, draw)
    }

    public func show(
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.showSubsurface(subsurfaceID, damage: damage, draw)
    }

    public func redraw(
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.redrawSubsurface(subsurfaceID, damage: nil, draw)
    }

    public func redraw(
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.redrawSubsurface(subsurfaceID, damage: damage, draw)
    }

    public func requestRedraw() async throws {
        try await display.requestSubsurfaceRedraw(subsurfaceID)
    }

    public func setInputRegion(_ region: SurfaceRegion?) async throws {
        try await display.setSubsurfaceInputRegion(subsurfaceID, region)
    }

    public func setOpaqueRegion(_ region: SurfaceRegion?) async throws {
        try await display.setSubsurfaceOpaqueRegion(subsurfaceID, region)
    }

    public func setPosition(_ position: LogicalOffset) async throws {
        try await display.setSubsurfacePosition(subsurfaceID, position)
    }

    public func placeAbove(_ sibling: Subsurface) async throws {
        guard sibling.isOwned(by: display) else {
            throw ClientError.display(.foreignSubsurface(sibling.id))
        }

        try await display.placeSubsurface(subsurfaceID, above: sibling.subsurfaceID)
    }

    public func placeBelow(_ sibling: Subsurface) async throws {
        guard sibling.isOwned(by: display) else {
            throw ClientError.display(.foreignSubsurface(sibling.id))
        }

        try await display.placeSubsurface(subsurfaceID, below: sibling.subsurfaceID)
    }

    public func setSynchronized() async throws {
        try await display.setSubsurfaceSynchronized(subsurfaceID)
    }

    public func setDesynchronized() async throws {
        try await display.setSubsurfaceDesynchronized(subsurfaceID)
    }

    public func close() async {
        await display.closeSubsurface(subsurfaceID)
    }

    public var isClosed: Bool {
        get async throws {
            try await display.subsurfaceIsClosed(subsurfaceID)
        }
    }

    public var needsRedraw: Bool {
        get async throws {
            try await display.subsurfaceNeedsRedraw(subsurfaceID)
        }
    }

    public var geometry: SurfaceGeometry {
        get async throws {
            try await display.subsurfaceGeometry(subsurfaceID)
        }
    }

    public static func == (lhs: Subsurface, rhs: Subsurface) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}
