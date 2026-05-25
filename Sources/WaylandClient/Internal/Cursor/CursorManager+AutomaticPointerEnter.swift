import WaylandCursor
import WaylandRaw

extension CursorManager {
    package func applyAutomaticPointerEnterCursor(
        to seatID: RawSeatID,
        serial explicitSerial: UInt32
    ) throws -> CursorRequestResult {
        let cursor = desiredCursor.cursor
        switch cursor.kind {
        case .hidden:
            return try applyAutomaticHiddenCursor(
                cursor,
                to: seatID,
                serial: explicitSerial
            )
        case .named:
            return try applyAutomaticNamedCursor(to: seatID, serial: explicitSerial)
        }
    }

    private func applyAutomaticHiddenCursor(
        _ cursor: PointerCursor,
        to seatID: RawSeatID,
        serial explicitSerial: UInt32
    ) throws -> CursorRequestResult {
        let rawResult = backend.setPointerCursor(
            seatID: seatID,
            serial: explicitSerial,
            surface: nil,
            hotspotX: 0,
            hotspotY: 0
        )
        guard case .set = rawResult else {
            throw AutomaticPointerEnterFailure.cursorRequest(
                pointerCursorRequestFailure(
                    seatID: seatID,
                    cursor: cursor,
                    rawResult: rawResult
                )
            )
        }

        markCursorApplied(.hidden(serial: explicitSerial), for: seatID)
        return .hidden(seatID: publicSeatID(seatID), serial: explicitSerial)
    }

    private func applyAutomaticNamedCursor(
        to seatID: RawSeatID,
        serial explicitSerial: UInt32
    ) throws -> CursorRequestResult {
        if backend.supportsCursorShape, let shape = desiredCursor.cursor.cursorShapeName {
            return try applyAutomaticShapeCursor(to: seatID, serial: explicitSerial, shape: shape)
        }

        let resolved = try automaticResolvedCursor(for: seatID)
        let surface = try automaticCursorSurface(for: seatID)

        surface.attach(resolved.image)
        surface.commit()

        let rawResult = backend.setPointerCursor(
            seatID: seatID,
            serial: explicitSerial,
            surface: surface,
            hotspotX: resolved.image.hotspotX,
            hotspotY: resolved.image.hotspotY
        )

        switch rawResult {
        case .set:
            markCursorApplied(
                .named(
                    cursor: resolved.cursor,
                    serial: explicitSerial,
                    surfaceID: surface.objectID
                ),
                for: seatID
            )
            return .set(
                seatID: publicSeatID(seatID),
                serial: explicitSerial,
                cursor: resolved.cursor
            )
        case .skippedNoPointer, .skippedUnknownSeat:
            throw AutomaticPointerEnterFailure.cursorRequest(
                pointerCursorRequestFailure(
                    seatID: seatID,
                    cursor: desiredCursor.cursor,
                    rawResult: rawResult
                )
            )
        }
    }

    private func applyAutomaticShapeCursor(
        to seatID: RawSeatID,
        serial explicitSerial: UInt32,
        shape: RawCursorShapeName
    ) throws -> CursorRequestResult {
        let rawResult = try backend.setPointerCursorShape(
            seatID: seatID,
            serial: explicitSerial,
            shape: shape
        )

        switch rawResult {
        case .set:
            markCursorApplied(
                .named(cursor: desiredCursor.cursor, serial: explicitSerial, surfaceID: nil),
                for: seatID
            )
            return .set(
                seatID: publicSeatID(seatID),
                serial: explicitSerial,
                cursor: desiredCursor.cursor
            )
        case .skippedNoPointer, .skippedUnknownSeat:
            throw AutomaticPointerEnterFailure.cursorRequest(
                pointerCursorRequestFailure(
                    seatID: seatID,
                    cursor: desiredCursor.cursor,
                    rawResult: rawResult
                )
            )
        }
    }

    private func automaticResolvedCursor(for seatID: RawSeatID) throws
        -> ResolvedPointerCursorImage
    {
        do {
            return try cachedResolvedDesiredCursor(size: cursorSize(for: seatID))
        } catch CursorError.missingCursor(let name) {
            throw CursorError.missingCursor(name)
        } catch {
            throw AutomaticPointerEnterFailure.cursorImageResolution(String(describing: error))
        }
    }

    private func automaticCursorSurface(
        for seatID: RawSeatID
    ) throws -> CursorManagerSurface {
        do {
            return try cursorSurface(for: seatID)
        } catch {
            throw AutomaticPointerEnterFailure.cursorSurfaceCreation(String(describing: error))
        }
    }
}
