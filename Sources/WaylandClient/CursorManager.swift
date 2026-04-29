import WaylandCursor
import WaylandRaw

package enum CursorRequestResult: Equatable, Sendable {
    case set(seatID: SeatID, serial: UInt32, cursor: PointerCursor)
    case hidden(seatID: SeatID, serial: UInt32)
    case skippedNoPointerFocus(seatID: SeatID)
    case skippedMissingCursor(name: String)
    case failed(String)
}

package protocol RawInputEventObserving: AnyObject {
    func observe(_ rawEvent: RawInputEvent)
}

package protocol CursorManagerSurface: AnyObject {
    var objectID: RawObjectID? { get }

    func attach(_ image: CursorImage)
    func commit()
    func destroy()
}

package protocol CursorManagerBackend: AnyObject {
    func preconditionIsOwnerThread()
    func cursorImage(named name: String) throws -> CursorImage
    func createCursorSurface(for seatID: RawSeatID) throws -> CursorManagerSurface
    func setPointerCursor(
        seatID: RawSeatID,
        serial: UInt32,
        surface: CursorManagerSurface?,
        hotspotX: Int32,
        hotspotY: Int32
    ) -> RawPointerCursorResult
}

package final class CursorManager: RawInputEventObserving {
    private let backend: CursorManagerBackend
    private let configuration: CursorConfiguration
    private var desiredCursor: PointerCursor
    private var registeredSurfaceIDs: Set<RawObjectID> = []
    private var focusedSurfaceBySeat: [RawSeatID: RawObjectID] = [:]
    private var focusedPointerSeatIDs: Set<RawSeatID> = []
    private var latestPointerEnterSerialBySeat: [RawSeatID: UInt32] = [:]
    private var cursorSurfaceBySeat: [RawSeatID: CursorManagerSurface] = [:]

    package private(set) var requestResults: [CursorRequestResult] = []

    init(
        connection rawConnection: RawDisplayConnection,
        configuration cursorConfiguration: CursorConfiguration
    ) throws {
        try Self.validate(cursorConfiguration)
        backend = try LiveCursorManagerBackend(
            connection: rawConnection,
            configuration: cursorConfiguration
        )
        configuration = cursorConfiguration
        desiredCursor = cursorConfiguration.fallbackCursor
    }

    package init(
        backend cursorBackend: CursorManagerBackend,
        configuration cursorConfiguration: CursorConfiguration
    ) throws {
        try Self.validate(cursorConfiguration)
        cursorBackend.preconditionIsOwnerThread()

        backend = cursorBackend
        configuration = cursorConfiguration
        desiredCursor = cursorConfiguration.fallbackCursor
    }

    var pointerCursor: PointerCursor {
        desiredCursor
    }

    func register(surfaceID: RawObjectID) {
        registeredSurfaceIDs.insert(surfaceID)
    }

    func unregister(surfaceID: RawObjectID) {
        registeredSurfaceIDs.remove(surfaceID)

        for (seatID, focusedSurfaceID) in focusedSurfaceBySeat
        where focusedSurfaceID == surfaceID {
            focusedSurfaceBySeat[seatID] = nil
            focusedPointerSeatIDs.remove(seatID)
        }
    }

    func setPointerCursor(_ cursor: PointerCursor) {
        backend.preconditionIsOwnerThread()
        desiredCursor = cursor

        for seatID in focusedPointerSeatIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
            applyCursor(to: seatID)
        }
    }

    package func observe(_ rawEvent: RawInputEvent) {
        backend.preconditionIsOwnerThread()

        switch rawEvent.kind {
        case .pointer(.enter(let enter)):
            handlePointerEnter(enter, seatID: rawEvent.seatID)
        case .pointer(.leave(let leave)):
            handlePointerLeave(leave, seatID: rawEvent.seatID)
        case .seat(let snapshot):
            if !snapshot.activeCapabilities.contains(.pointer) {
                clearSeat(rawEvent.seatID)
            }
        case .seatRemoved:
            clearSeat(rawEvent.seatID)
        default:
            break
        }
    }

    private func handlePointerEnter(_ enter: RawPointerEnter, seatID: RawSeatID) {
        latestPointerEnterSerialBySeat[seatID] = enter.serial

        guard let surfaceID = enter.surfaceID,
            registeredSurfaceIDs.contains(surfaceID)
        else {
            return
        }

        focusedSurfaceBySeat[seatID] = surfaceID
        focusedPointerSeatIDs.insert(seatID)
        applyCursor(to: seatID)
    }

    private func handlePointerLeave(_ leave: RawPointerLeave, seatID: RawSeatID) {
        guard focusedSurfaceBySeat[seatID] == leave.surfaceID else { return }

        focusedSurfaceBySeat[seatID] = nil
        focusedPointerSeatIDs.remove(seatID)
    }

    private func applyCursor(to seatID: RawSeatID) {
        guard focusedPointerSeatIDs.contains(seatID),
            let serial = latestPointerEnterSerialBySeat[seatID]
        else {
            requestResults.append(.skippedNoPointerFocus(seatID: publicSeatID(seatID)))
            return
        }

        switch desiredCursor.kind {
        case .hidden:
            _ = backend.setPointerCursor(
                seatID: seatID,
                serial: serial,
                surface: nil,
                hotspotX: 0,
                hotspotY: 0
            )
            requestResults.append(.hidden(seatID: publicSeatID(seatID), serial: serial))
        case .named:
            applyNamedCursor(to: seatID, serial: serial)
        }
    }

    private func applyNamedCursor(to seatID: RawSeatID, serial: UInt32) {
        do {
            let resolved = try resolveCursorImage(desiredCursor)
            let surface = try cursorSurface(for: seatID)

            surface.attach(resolved.image)
            surface.commit()

            let rawResult = backend.setPointerCursor(
                seatID: seatID,
                serial: serial,
                surface: surface,
                hotspotX: resolved.image.hotspotX,
                hotspotY: resolved.image.hotspotY
            )

            switch rawResult {
            case .set:
                requestResults.append(
                    .set(seatID: publicSeatID(seatID), serial: serial, cursor: resolved.cursor)
                )
            case .skippedNoPointer, .skippedUnknownSeat:
                requestResults.append(.failed(String(describing: rawResult)))
            }
        } catch CursorError.missingCursor(let name) {
            requestResults.append(.skippedMissingCursor(name: name))
        } catch {
            requestResults.append(.failed(String(describing: error)))
        }
    }

    private func resolveCursorImage(_ cursor: PointerCursor) throws -> (
        cursor: PointerCursor, image: CursorImage
    ) {
        guard let name = cursor.name else {
            throw CursorError.missingCursor("hidden")
        }

        do {
            return try (cursor, backend.cursorImage(named: name))
        } catch {
            guard cursor != configuration.fallbackCursor,
                let fallbackName = configuration.fallbackCursor.name
            else {
                throw error
            }

            return try (configuration.fallbackCursor, backend.cursorImage(named: fallbackName))
        }
    }

    private func cursorSurface(for seatID: RawSeatID) throws -> CursorManagerSurface {
        if let surface = cursorSurfaceBySeat[seatID] {
            return surface
        }

        let surface = try backend.createCursorSurface(for: seatID)
        cursorSurfaceBySeat[seatID] = surface
        return surface
    }

    private func clearSeat(_ seatID: RawSeatID) {
        latestPointerEnterSerialBySeat[seatID] = nil
        focusedSurfaceBySeat[seatID] = nil
        focusedPointerSeatIDs.remove(seatID)
        cursorSurfaceBySeat.removeValue(forKey: seatID)?.destroy()
    }

    private func publicSeatID(_ seatID: RawSeatID) -> SeatID {
        SeatID(rawValue: seatID.rawValue)
    }

    deinit {
        for surface in cursorSurfaceBySeat.values {
            surface.destroy()
        }
    }

    private static func validate(_ configuration: CursorConfiguration) throws {
        guard configuration.size > 0 else {
            throw ClientError.invalidCursorConfiguration(
                "Cursor size must be greater than zero"
            )
        }
    }
}

private final class LiveCursorManagerBackend: CursorManagerBackend {
    private let connection: RawDisplayConnection
    private let theme: CursorTheme

    init(
        connection rawConnection: RawDisplayConnection,
        configuration cursorConfiguration: CursorConfiguration
    ) throws {
        rawConnection.preconditionIsOwnerThread()

        connection = rawConnection
        theme = try CursorTheme(
            shm: rawConnection.cursorSharedMemory(),
            name: cursorConfiguration.themeName,
            size: cursorConfiguration.size
        )
    }

    func preconditionIsOwnerThread() {
        connection.preconditionIsOwnerThread()
    }

    func cursorImage(named name: String) throws -> CursorImage {
        try theme.cursor(named: name).image
    }

    func createCursorSurface(for _: RawSeatID) throws -> CursorManagerSurface {
        try LiveCursorManagerSurface(surface: connection.createRawSurface())
    }

    func setPointerCursor(
        seatID: RawSeatID,
        serial: UInt32,
        surface: CursorManagerSurface?,
        hotspotX: Int32,
        hotspotY: Int32
    ) -> RawPointerCursorResult {
        let rawSurface: RawSurface?
        if let surface {
            guard let liveSurface = surface as? LiveCursorManagerSurface else {
                preconditionFailure("Live cursor backend received a non-live cursor surface")
            }
            rawSurface = liveSurface.rawSurface
        } else {
            rawSurface = nil
        }

        return connection.setPointerCursor(
            seatID: seatID,
            serial: serial,
            surface: rawSurface,
            hotspotX: hotspotX,
            hotspotY: hotspotY
        )
    }
}

private final class LiveCursorManagerSurface: CursorManagerSurface {
    let rawSurface: RawSurface

    init(surface: RawSurface) {
        rawSurface = surface
    }

    var objectID: RawObjectID? {
        rawSurface.objectID
    }

    func attach(_ image: CursorImage) {
        rawSurface.attachBorrowedBuffer(image.buffer)
        rawSurface.damageFullBuffer(width: image.width, height: image.height)
    }

    func commit() {
        rawSurface.commit()
    }

    func destroy() {
        rawSurface.destroy()
    }
}
