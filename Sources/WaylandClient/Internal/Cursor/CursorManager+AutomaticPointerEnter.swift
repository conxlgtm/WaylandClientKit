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
        case .customImage(let image):
            return try applyAutomaticCustomImageCursor(
                cursor,
                image: image,
                to: seatID,
                serial: explicitSerial
            )
        case .animated(let animation):
            return try applyAutomaticAnimatedCursor(
                cursor,
                animation: animation,
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

        detachCursorSurfaceIfPresent(for: seatID)
        clearCursorAnimation(for: seatID)
        markCursorApplied(.hidden(serial: explicitSerial), for: seatID)
        return .hidden(seatID: publicSeatID(seatID), serial: explicitSerial)
    }

    private func applyAutomaticCustomImageCursor(
        _ cursor: PointerCursor,
        image: PointerCursorImage,
        to seatID: RawSeatID,
        serial explicitSerial: UInt32
    ) throws -> CursorRequestResult {
        let surface = try automaticCursorSurface(for: seatID)
        let cursorImage: CursorImage
        do {
            cursorImage = try backend.cursorImage(from: image)
        } catch {
            throw AutomaticPointerEnterFailure.cursorImageResolution(String(describing: error))
        }

        let bufferScale = PositiveInt32(unchecked: 1)
        let rawResult = setSurfaceBackedCursor(
            cursorImage,
            on: surface,
            for: seatID,
            serial: explicitSerial,
            bufferScale: bufferScale
        )

        switch rawResult {
        case .set:
            clearCursorAnimation(for: seatID)
            markCursorApplied(
                .customImage(cursor: cursor, serial: explicitSerial, surfaceID: surface.objectID),
                for: seatID
            )
            return .set(
                seatID: publicSeatID(seatID),
                serial: explicitSerial,
                cursor: cursor
            )
        case .skippedNoPointer, .skippedUnknownSeat:
            throw AutomaticPointerEnterFailure.cursorRequest(
                pointerCursorRequestFailure(
                    seatID: seatID,
                    cursor: cursor,
                    rawResult: rawResult
                )
            )
        }
    }

    private func applyAutomaticAnimatedCursor(
        _ cursor: PointerCursor,
        animation: AnimatedPointerCursor,
        to seatID: RawSeatID,
        serial explicitSerial: UInt32
    ) throws -> CursorRequestResult {
        let surface = try automaticCursorSurface(for: seatID)
        let frames: [AnimatedCursorFrame]
        do {
            frames = try resolvedAnimatedFrames(animation)
        } catch {
            throw AutomaticPointerEnterFailure.cursorImageResolution(String(describing: error))
        }

        var animationState: CursorAnimationState
        do {
            animationState = try CursorAnimationState(frames: frames)
        } catch {
            throw AutomaticPointerEnterFailure.cursorImageResolution(String(describing: error))
        }

        let bufferScale = PositiveInt32(unchecked: 1)
        let currentFrame = animationState.currentFrame
        let rawResult = setSurfaceBackedCursor(
            currentFrame.image,
            on: surface,
            for: seatID,
            serial: explicitSerial,
            bufferScale: bufferScale
        )

        switch rawResult {
        case .set:
            markCursorAnimationState(
                animationState.isAnimated ? animationState : nil,
                for: seatID
            )
            markCursorApplied(
                .animated(
                    cursor: cursor,
                    serial: explicitSerial,
                    surfaceID: surface.objectID,
                    frameIndex: animationState.currentFrameIndex
                ),
                for: seatID
            )
            return .set(
                seatID: publicSeatID(seatID),
                serial: explicitSerial,
                cursor: cursor
            )
        case .skippedNoPointer, .skippedUnknownSeat:
            throw AutomaticPointerEnterFailure.cursorRequest(
                pointerCursorRequestFailure(
                    seatID: seatID,
                    cursor: cursor,
                    rawResult: rawResult
                )
            )
        }
    }

    private func applyAutomaticNamedCursor(
        to seatID: RawSeatID,
        serial explicitSerial: UInt32
    ) throws -> CursorRequestResult {
        if backend.supportsCursorShape, let shape = desiredCursor.cursor.cursorShapeName {
            return try applyAutomaticShapeCursor(to: seatID, serial: explicitSerial, shape: shape)
        }

        let cursorResolution = try automaticCursorResolution(for: seatID)
        let resolved = try automaticResolvedCursor(size: cursorResolution.size)
        let surface = try automaticCursorSurface(for: seatID)

        let rawResult = setSurfaceBackedCursor(
            resolved.image,
            on: surface,
            for: seatID,
            serial: explicitSerial,
            bufferScale: cursorResolution.bufferScale
        )

        switch rawResult {
        case .set:
            clearCursorAnimation(for: seatID)
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
            clearCursorAnimation(for: seatID)
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

    private func automaticCursorResolution(for seatID: RawSeatID) throws
        -> CursorScaleResolution
    {
        do {
            return try cursorResolution(for: seatID)
        } catch {
            throw AutomaticPointerEnterFailure.cursorImageResolution(String(describing: error))
        }
    }

    private func automaticResolvedCursor(size: CursorSize) throws -> ResolvedPointerCursorImage {
        do {
            return try cachedResolvedDesiredCursor(size: size)
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
