// swiftlint:disable file_length

import WaylandCursor
import WaylandRaw

package protocol RawInputEventObserving: AnyObject {
    @discardableResult
    func observe(_ rawEvent: RawInputEvent) -> [InputEvent]
}

package protocol CursorManagerSurface: AnyObject {
    var objectID: RawObjectID? { get }

    func attach(_ image: CursorImage)
    func detach()
    func commit()
    func destroy()
}

package protocol CursorManagerBackend: AnyObject {
    var supportsCursorShape: Bool { get }

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
    func setPointerCursorShape(
        seatID: RawSeatID,
        serial: UInt32,
        shape: RawCursorShapeName
    ) throws -> RawPointerCursorResult
}

// swiftlint:disable:next type_body_length
package final class CursorManager: RawInputEventObserving {
    package let backend: CursorManagerBackend
    private let configuration: CursorConfiguration
    package var desiredCursor: DesiredPointerCursorState
    private var registeredSurfaceIDs: Set<RawObjectID> = []
    private var cursorStateBySeat: [RawSeatID: PointerCursorSeatState] = [:]
    private var isShutdown = false

    init(
        connection rawConnection: RawDisplayConnection,
        configuration cursorConfiguration: CursorConfiguration
    ) throws {
        backend = try LiveCursorManagerBackend(
            connection: rawConnection,
            configuration: cursorConfiguration
        )
        configuration = cursorConfiguration
        desiredCursor = DesiredPointerCursorState(cursor: cursorConfiguration.fallbackCursor)
    }

    package init(
        backend cursorBackend: CursorManagerBackend,
        configuration cursorConfiguration: CursorConfiguration
    ) throws {
        cursorBackend.preconditionIsOwnerThread()

        backend = cursorBackend
        configuration = cursorConfiguration
        desiredCursor = DesiredPointerCursorState(cursor: cursorConfiguration.fallbackCursor)
    }

    var pointerCursor: PointerCursor { desiredCursor.cursor }

    func register(surfaceID: RawObjectID) {
        guard !isShutdown else { return }
        registeredSurfaceIDs.insert(surfaceID)
    }

    func unregister(surfaceID: RawObjectID) {
        guard !isShutdown else { return }
        registeredSurfaceIDs.remove(surfaceID)

        for seatID in Array(cursorStateBySeat.keys) {
            let effects = reduceSeatState(.registeredSurfaceRemoved(surfaceID), for: seatID)
            interpret(effects, seatID: seatID)
        }
    }

    @discardableResult
    func setPointerCursor(_ cursor: PointerCursor) throws -> [CursorRequestResult] {
        backend.preconditionIsOwnerThread()
        guard !isShutdown else { return [] }
        let resolvedCursor = try resolvedCursorIfNeeded(cursor)
        desiredCursor = DesiredPointerCursorState(cursor: cursor, resolved: resolvedCursor)

        var results: [CursorRequestResult] = []
        for seatID in focusedPointerSeatIDs() {
            results.append(try applyCursor(to: seatID, resolvedCursor: resolvedCursor))
        }

        return results
    }

    @discardableResult
    package func observe(_ rawEvent: RawInputEvent) -> [InputEvent] {
        backend.preconditionIsOwnerThread()
        guard !isShutdown else { return [] }

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
        let event: PointerCursorSeatEvent
        if let surfaceID = enter.surfaceID,
            registeredSurfaceIDs.contains(surfaceID)
        {
            event = .managedPointerEntered(
                surfaceID: surfaceID,
                serial: enter.serial,
                sourceEvent: rawEvent
            )
        } else {
            event = .unmanagedPointerEntered
        }

        let effects = reduceSeatState(event, for: rawEvent.seatID)
        return interpret(effects, seatID: rawEvent.seatID)
    }

    private func handlePointerLeave(_ leave: RawPointerLeave, seatID: RawSeatID) {
        let effects = reduceSeatState(.pointerLeft(surfaceID: leave.surfaceID), for: seatID)
        interpret(effects, seatID: seatID)
    }

    private func resolvedCursorIfNeeded(
        _ cursor: PointerCursor
    ) throws -> ResolvedPointerCursorImage? {
        guard case .named = cursor.kind else { return nil }
        if backend.supportsCursorShape, cursor.cursorShapeName != nil {
            return nil
        }

        return try resolveCursorImage(cursor)
    }

    private func applyCursor(
        to seatID: RawSeatID,
        serial explicitSerial: UInt32? = nil,
        resolvedCursor: ResolvedPointerCursorImage? = nil
    ) throws -> CursorRequestResult {
        guard let serial = explicitSerial ?? cursorStateBySeat[seatID]?.focus.enterSerial else {
            return .skippedNoPointerFocus(seatID: publicSeatID(seatID))
        }

        let cursor = desiredCursor.cursor
        switch cursor.kind {
        case .hidden:
            let rawResult = backend.setPointerCursor(
                seatID: seatID,
                serial: serial,
                surface: nil,
                hotspotX: 0,
                hotspotY: 0
            )
            guard case .set = rawResult else {
                throw cursorRequestFailure(
                    seatID: seatID,
                    cursor: cursor,
                    rawResult: rawResult
                )
            }

            markCursorApplied(.hidden(serial: serial), for: seatID)
            return .hidden(seatID: publicSeatID(seatID), serial: serial)
        case .named:
            if backend.supportsCursorShape, let shape = cursor.cursorShapeName {
                return try applyShapeCursor(
                    to: seatID,
                    serial: serial,
                    cursor: cursor,
                    shape: shape
                )
            }

            let resolved = try resolvedCursor ?? cachedResolvedDesiredCursor()
            return try applyNamedCursor(
                to: seatID,
                serial: serial,
                resolvedCursor: resolved
            )
        }
    }

    private func applyShapeCursor(
        to seatID: RawSeatID,
        serial: UInt32,
        cursor: PointerCursor,
        shape: RawCursorShapeName
    ) throws -> CursorRequestResult {
        let rawResult = try backend.setPointerCursorShape(
            seatID: seatID,
            serial: serial,
            shape: shape
        )

        switch rawResult {
        case .set:
            markCursorApplied(.named(cursor: cursor, serial: serial, surfaceID: nil), for: seatID)
            return .set(seatID: publicSeatID(seatID), serial: serial, cursor: cursor)
        case .skippedNoPointer, .skippedUnknownSeat:
            throw cursorRequestFailure(
                seatID: seatID,
                cursor: cursor,
                rawResult: rawResult
            )
        }
    }

    private func applyNamedCursor(
        to seatID: RawSeatID,
        serial: UInt32,
        resolvedCursor resolved: ResolvedPointerCursorImage
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
            markCursorApplied(
                .named(cursor: resolved.cursor, serial: serial, surfaceID: surface.objectID),
                for: seatID
            )
            return .set(seatID: publicSeatID(seatID), serial: serial, cursor: resolved.cursor)
        case .skippedNoPointer, .skippedUnknownSeat:
            throw cursorRequestFailure(
                seatID: seatID,
                cursor: desiredCursor.cursor,
                rawResult: rawResult
            )
        }
    }

    package func cachedResolvedDesiredCursor() throws -> ResolvedPointerCursorImage {
        if let resolvedDesiredCursor = desiredCursor.resolvedImage {
            return resolvedDesiredCursor
        }

        let resolved = try resolveCursorImage(desiredCursor.cursor)
        desiredCursor.cache(resolved)
        return resolved
    }

    private func resolveCursorImage(_ cursor: PointerCursor) throws -> ResolvedPointerCursorImage {
        guard let name = cursor.name else {
            throw CursorError.missingCursor("hidden")
        }

        do {
            return try ResolvedPointerCursorImage(
                cursor: cursor,
                image: backend.cursorImage(named: name)
            )
        } catch {
            guard cursor != configuration.fallbackCursor,
                let fallbackName = configuration.fallbackCursor.name
            else {
                throw error
            }

            return try ResolvedPointerCursorImage(
                cursor: configuration.fallbackCursor,
                image: backend.cursorImage(named: fallbackName)
            )
        }
    }

    package func cursorSurface(for seatID: RawSeatID) throws -> CursorManagerSurface {
        if let surface = cursorStateBySeat[seatID]?.cursorSurface {
            return surface
        }

        let surface = try backend.createCursorSurface(for: seatID)
        var state = cursorStateBySeat[seatID] ?? PointerCursorSeatState()
        state.cursorSurface = surface
        cursorStateBySeat[seatID] = state
        return surface
    }

    private func clearSeat(_ seatID: RawSeatID) {
        let effects = reduceSeatState(.pointerUnavailable, for: seatID)
        interpret(effects, seatID: seatID)
    }

    package func shutdown() {
        shutdown(preconditionOwnerThread: true)
    }

    deinit {
        shutdown(preconditionOwnerThread: false)
    }

    private func shutdown(preconditionOwnerThread: Bool) {
        if preconditionOwnerThread {
            backend.preconditionIsOwnerThread()
        }
        guard !isShutdown else { return }

        isShutdown = true
        let surfaces = cursorStateBySeat.values.compactMap(\.cursorSurface)
        cursorStateBySeat.removeAll(keepingCapacity: false)
        registeredSurfaceIDs.removeAll(keepingCapacity: false)
        desiredCursor = DesiredPointerCursorState(cursor: configuration.fallbackCursor)

        for surface in surfaces {
            surface.detach()
            surface.commit()
            surface.destroy()
        }
    }

    private func destroyCursorSurface(_ surface: CursorManagerSurface) {
        surface.detach()
        surface.commit()
        surface.destroy()
    }

    private func cursorRequestFailure(
        seatID rawSeatID: RawSeatID,
        cursor: PointerCursor,
        rawResult: RawPointerCursorResult
    ) -> ClientError {
        .cursor(
            .requestFailed(
                pointerCursorRequestFailure(
                    seatID: rawSeatID,
                    cursor: cursor,
                    rawResult: rawResult
                )
            )
        )
    }

    package func pointerCursorRequestFailure(
        seatID rawSeatID: RawSeatID,
        cursor: PointerCursor,
        rawResult: RawPointerCursorResult
    ) -> PointerCursorRequestFailure {
        let rawResultSeatID: RawSeatID
        let backendResult: PointerCursorBackendResult

        switch rawResult {
        case .set:
            preconditionFailure("successful cursor result cannot describe a failure")
        case .skippedNoPointer(let seatID):
            rawResultSeatID = seatID
            backendResult = .skippedNoPointer
        case .skippedUnknownSeat(let seatID):
            rawResultSeatID = seatID
            backendResult = .skippedUnknownSeat
        }

        precondition(
            rawResultSeatID == rawSeatID,
            "cursor backend failure seat must match requested seat"
        )

        return PointerCursorRequestFailure(
            seatID: publicSeatID(rawSeatID),
            requestedCursor: cursor,
            backendResult: backendResult
        )
    }
}

extension CursorManager {
    private func focusedPointerSeatIDs() -> [RawSeatID] {
        cursorStateBySeat
            .filter(\.value.focus.isFocused)
            .map(\.key)
            .sortedByRawValue()
    }

    private func reduceSeatState(
        _ event: PointerCursorSeatEvent,
        for seatID: RawSeatID
    ) -> [PointerCursorSeatEffect] {
        var state = cursorStateBySeat[seatID] ?? PointerCursorSeatState()
        let effects = state.reduce(event)

        if state.isEmpty {
            cursorStateBySeat[seatID] = nil
        } else {
            cursorStateBySeat[seatID] = state
        }

        return effects
    }

    package func markCursorApplied(
        _ application: PointerCursorApplicationState,
        for seatID: RawSeatID
    ) {
        guard var state = cursorStateBySeat[seatID] else {
            return
        }

        state.markApplied(application)
        cursorStateBySeat[seatID] = state
    }

    @discardableResult
    private func interpret(
        _ effects: [PointerCursorSeatEffect],
        seatID: RawSeatID
    ) -> [InputEvent] {
        var inputEvents: [InputEvent] = []

        for effect in effects {
            switch effect {
            case .applyCursor(let serial, let sourceEvent):
                inputEvents.append(
                    contentsOf: recordCursorRequest(
                        to: seatID,
                        serial: serial,
                        rawEvent: sourceEvent
                    ))
            case .destroyCursorSurface(let surface):
                destroyCursorSurface(surface)
            }
        }

        return inputEvents
    }

    package func publicSeatID(_ seatID: RawSeatID) -> SeatID {
        SeatID(seatID)
    }

    private func recordCursorRequest(
        to seatID: RawSeatID,
        serial: UInt32,
        rawEvent: RawInputEvent
    ) -> [InputEvent] {
        if let diagnostic = desiredCursor.unavailableDiagnostic {
            switch diagnostic {
            case .missingCursor:
                return automaticCursorDiagnosticEvents(diagnostic, rawEvent: rawEvent)
            case .automaticPointerEnterFailed:
                break
            }
        }

        do {
            _ = try applyAutomaticPointerEnterCursor(to: seatID, serial: serial)
            return []
        } catch CursorError.missingCursor(let name) {
            let diagnostic = CursorDiagnostic.missingCursor(name: name)
            desiredCursor.cacheUnavailable(diagnostic)
            return automaticCursorDiagnosticEvents(diagnostic, rawEvent: rawEvent)
        } catch let failure as AutomaticPointerEnterFailure {
            let diagnostic = CursorDiagnostic.automaticPointerEnterFailed(failure)
            return automaticCursorDiagnosticEvents(diagnostic, rawEvent: rawEvent)
        } catch ClientError.cursor(.requestFailed(let failure)) {
            let diagnostic = CursorDiagnostic.automaticPointerEnterFailed(
                .cursorRequest(failure)
            )
            return automaticCursorDiagnosticEvents(diagnostic, rawEvent: rawEvent)
        } catch {
            let diagnostic = CursorDiagnostic.automaticPointerEnterFailed(
                .cursorApplication(String(describing: error))
            )
            return automaticCursorDiagnosticEvents(diagnostic, rawEvent: rawEvent)
        }
    }

    private func automaticCursorDiagnosticEvents(
        _ diagnostic: CursorDiagnostic,
        rawEvent: RawInputEvent
    ) -> [InputEvent] {
        let event = cursorDiagnostic(rawEvent, payload: diagnostic)
        return [event]
    }

    private func cursorDiagnostic(
        _ rawEvent: RawInputEvent,
        payload: CursorDiagnostic
    ) -> InputEvent {
        InputEvent(
            sequence: rawEvent.sequence,
            seatID: publicSeatID(rawEvent.seatID),
            target: .display,
            kind: .diagnostic(
                InputDiagnostic(
                    .cursor(payload)
                )
            )
        )
    }
}
