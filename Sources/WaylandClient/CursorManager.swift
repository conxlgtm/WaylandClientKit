import WaylandCursor
import WaylandRaw

public enum CursorRequestResult: Equatable, Sendable {
    case set(seatID: SeatID, serial: UInt32, cursor: PointerCursor)
    case hidden(seatID: SeatID, serial: UInt32)
    case skippedNoPointerFocus(seatID: SeatID)
}

package enum CursorRequestRecord: Equatable, Sendable {
    case set(seatID: SeatID, serial: UInt32, cursor: PointerCursor)
    case hidden(seatID: SeatID, serial: UInt32)
    case skippedNoPointerFocus(seatID: SeatID)
    case skippedMissingCursor(name: String)
    case failed(String)

    init(_ result: CursorRequestResult) {
        switch result {
        case .set(let seatID, let serial, let cursor):
            self = .set(seatID: seatID, serial: serial, cursor: cursor)
        case .hidden(let seatID, let serial):
            self = .hidden(seatID: seatID, serial: serial)
        case .skippedNoPointerFocus(let seatID):
            self = .skippedNoPointerFocus(seatID: seatID)
        }
    }
}

package protocol RawInputEventObserving: AnyObject {
    @discardableResult
    func observe(_ rawEvent: RawInputEvent) -> [InputEvent]
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
    private typealias ResolvedCursorImage = (cursor: PointerCursor, image: CursorImage)

    private let backend: CursorManagerBackend
    private let configuration: CursorConfiguration
    private var desiredCursor: PointerCursor
    private var resolvedDesiredCursor: ResolvedCursorImage?
    private var registeredSurfaceIDs: Set<RawObjectID> = []
    private var focusedSurfaceBySeat: [RawSeatID: RawObjectID] = [:]
    private var focusedPointerSeatIDs: Set<RawSeatID> = []
    private var latestPointerEnterSerialBySeat: [RawSeatID: UInt32] = [:]
    private var cursorSurfaceBySeat: [RawSeatID: CursorManagerSurface] = [:]

    package private(set) var requestResults: [CursorRequestRecord] = []

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
        resolvedDesiredCursor = nil
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
        resolvedDesiredCursor = nil
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

    @discardableResult
    func setPointerCursor(_ cursor: PointerCursor) throws -> [CursorRequestResult] {
        backend.preconditionIsOwnerThread()
        let resolvedCursor = try resolvedCursorIfNeeded(cursor)
        desiredCursor = cursor
        resolvedDesiredCursor = resolvedCursor

        var results: [CursorRequestResult] = []
        for seatID in focusedPointerSeatIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
            results.append(try applyCursor(to: seatID, resolvedCursor: resolvedCursor))
        }

        requestResults.append(contentsOf: results.map(CursorRequestRecord.init))
        return results
    }

    @discardableResult
    package func observe(_ rawEvent: RawInputEvent) -> [InputEvent] {
        backend.preconditionIsOwnerThread()

        switch rawEvent.kind {
        case .pointer(.enter(let enter)):
            return handlePointerEnter(enter, rawEvent: rawEvent)
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

        return []
    }

    private func handlePointerEnter(
        _ enter: RawPointerEnter,
        rawEvent: RawInputEvent
    ) -> [InputEvent] {
        let seatID = rawEvent.seatID
        latestPointerEnterSerialBySeat[seatID] = enter.serial

        guard let surfaceID = enter.surfaceID,
            registeredSurfaceIDs.contains(surfaceID)
        else {
            return []
        }

        focusedSurfaceBySeat[seatID] = surfaceID
        focusedPointerSeatIDs.insert(seatID)
        return recordCursorRequest(to: seatID, rawEvent: rawEvent)
    }

    private func handlePointerLeave(_ leave: RawPointerLeave, seatID: RawSeatID) {
        guard focusedSurfaceBySeat[seatID] == leave.surfaceID else { return }

        focusedSurfaceBySeat[seatID] = nil
        focusedPointerSeatIDs.remove(seatID)
    }

    private func resolvedCursorIfNeeded(_ cursor: PointerCursor) throws -> ResolvedCursorImage? {
        guard case .named = cursor.kind else { return nil }

        return try resolveCursorImage(cursor)
    }

    private func applyCursor(
        to seatID: RawSeatID,
        resolvedCursor: ResolvedCursorImage? = nil
    ) throws -> CursorRequestResult {
        guard focusedPointerSeatIDs.contains(seatID),
            let serial = latestPointerEnterSerialBySeat[seatID]
        else {
            return .skippedNoPointerFocus(seatID: publicSeatID(seatID))
        }

        switch desiredCursor.kind {
        case .hidden:
            let rawResult = backend.setPointerCursor(
                seatID: seatID,
                serial: serial,
                surface: nil,
                hotspotX: 0,
                hotspotY: 0
            )
            guard case .set = rawResult else {
                throw ClientError.pointerCursorRequestFailed(String(describing: rawResult))
            }

            return .hidden(seatID: publicSeatID(seatID), serial: serial)
        case .named:
            let resolved = try resolvedCursor ?? cachedResolvedDesiredCursor()
            return try applyNamedCursor(
                to: seatID,
                serial: serial,
                resolvedCursor: resolved
            )
        }
    }

    private func applyNamedCursor(
        to seatID: RawSeatID,
        serial: UInt32,
        resolvedCursor resolved: ResolvedCursorImage
    ) throws
        -> CursorRequestResult
    {
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
            return .set(seatID: publicSeatID(seatID), serial: serial, cursor: resolved.cursor)
        case .skippedNoPointer, .skippedUnknownSeat:
            throw ClientError.pointerCursorRequestFailed(String(describing: rawResult))
        }
    }

    private func cachedResolvedDesiredCursor() throws -> ResolvedCursorImage {
        if let resolvedDesiredCursor {
            return resolvedDesiredCursor
        }

        let resolved = try resolveCursorImage(desiredCursor)
        resolvedDesiredCursor = resolved
        return resolved
    }

    private func resolveCursorImage(_ cursor: PointerCursor) throws -> ResolvedCursorImage {
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

        if let themeName = configuration.themeName {
            try CStringValidation.requireNonEmptyNoInteriorNUL(
                themeName,
                fieldName: "Cursor theme names",
                error: ClientError.invalidCursorConfiguration
            )
        }
    }
}

extension CursorManager {
    private func recordCursorRequest(
        to seatID: RawSeatID,
        rawEvent: RawInputEvent
    ) -> [InputEvent] {
        do {
            requestResults.append(CursorRequestRecord(try applyCursor(to: seatID)))
            return []
        } catch CursorError.missingCursor(let name) {
            requestResults.append(.skippedMissingCursor(name: name))
            let diagnostic = cursorDiagnostic(
                rawEvent,
                operation: "missingCursor",
                message: "cursor \(name) is unavailable"
            )
            return [diagnostic]
        } catch {
            let message = String(describing: error)
            requestResults.append(.failed(message))
            let diagnostic = cursorDiagnostic(
                rawEvent,
                operation: "automaticPointerEnter",
                message: message
            )
            return [diagnostic]
        }
    }

    private func cursorDiagnostic(
        _ rawEvent: RawInputEvent,
        operation: String,
        message: String
    ) -> InputEvent {
        InputEvent(
            sequence: rawEvent.sequence,
            seatID: publicSeatID(rawEvent.seatID),
            windowID: nil,
            kind: .diagnostic(
                InputDiagnostic(
                    operation: .cursor(operation),
                    message: message
                )
            )
        )
    }
}

private final class LiveCursorManagerBackend: CursorManagerBackend {
    private let connection: RawDisplayConnection
    private let configuration: CursorConfiguration
    private var theme: CursorTheme?

    init(
        connection rawConnection: RawDisplayConnection,
        configuration cursorConfiguration: CursorConfiguration
    ) throws {
        rawConnection.preconditionIsOwnerThread()

        connection = rawConnection
        configuration = cursorConfiguration
    }

    func preconditionIsOwnerThread() {
        connection.preconditionIsOwnerThread()
    }

    func cursorImage(named name: String) throws -> CursorImage {
        try cursorTheme().cursorImage(named: name)
    }

    private func cursorTheme() throws -> CursorTheme {
        if let theme {
            return theme
        }

        let loadedTheme = try CursorTheme(
            shm: connection.cursorSharedMemory(),
            name: configuration.themeName,
            size: configuration.size
        )
        theme = loadedTheme
        return loadedTheme
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
