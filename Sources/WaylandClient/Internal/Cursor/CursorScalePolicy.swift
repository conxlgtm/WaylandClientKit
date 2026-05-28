import WaylandRaw

package struct CursorOutputScale: Equatable, Sendable {
    package let outputID: OutputID
    package let scale: PositiveInt32

    package init(outputID cursorOutputID: OutputID, scale cursorOutputScale: PositiveInt32) {
        outputID = cursorOutputID
        scale = cursorOutputScale
    }

    package init(_ snapshot: RawOutputSnapshot) {
        outputID = OutputID(snapshot.id)
        scale = PositiveInt32(unchecked: snapshot.scale)
    }
}

package struct CursorScaleContext: Equatable, Sendable {
    package let seatID: SeatID
    package let focusedSurfaceID: RawObjectID
    package let focusedOutputs: [CursorOutputScale]
    package let availableOutputs: [CursorOutputScale]
    package let baseSize: CursorSize

    package init(
        seatID cursorSeatID: SeatID,
        focusedSurfaceID cursorFocusedSurfaceID: RawObjectID,
        focusedOutputs cursorFocusedOutputs: [CursorOutputScale],
        availableOutputs cursorAvailableOutputs: [CursorOutputScale],
        baseSize cursorBaseSize: CursorSize
    ) {
        seatID = cursorSeatID
        focusedSurfaceID = cursorFocusedSurfaceID
        focusedOutputs = cursorFocusedOutputs
        availableOutputs = cursorAvailableOutputs
        baseSize = cursorBaseSize
    }
}

package struct CursorScaleResolution: Equatable, Sendable {
    package let size: CursorSize
    package let bufferScale: PositiveInt32

    package init(size cursorSize: CursorSize, bufferScale cursorBufferScale: PositiveInt32) {
        size = cursorSize
        bufferScale = cursorBufferScale
    }
}

package enum CursorScalePolicy: Equatable, Sendable {
    case fixed
    case matchFocusedSurface
    case maximumOutputScale

    package func cursorResolution(
        in context: CursorScaleContext
    ) throws(CursorScalePolicyError) -> CursorScaleResolution {
        switch self {
        case .fixed:
            CursorScaleResolution(
                size: context.baseSize,
                bufferScale: PositiveInt32(unchecked: 1)
            )
        case .matchFocusedSurface:
            try scaledResolution(
                baseSize: context.baseSize,
                outputs: context.focusedOutputs
            )
        case .maximumOutputScale:
            try scaledResolution(
                baseSize: context.baseSize,
                outputs: context.availableOutputs
            )
        }
    }

    package func cursorSize(
        in context: CursorScaleContext
    ) throws(CursorScalePolicyError) -> CursorSize {
        try cursorResolution(in: context).size
    }

    private func scaledResolution(
        baseSize: CursorSize,
        outputs: [CursorOutputScale]
    ) throws(CursorScalePolicyError) -> CursorScaleResolution {
        guard let maximumScale = outputs.map(\.scale.rawValue).max() else {
            return CursorScaleResolution(
                size: baseSize,
                bufferScale: PositiveInt32(unchecked: 1)
            )
        }

        let scaledValue = Int64(baseSize.rawValue) * Int64(maximumScale)
        guard scaledValue <= Int64(Int32.max) else {
            throw .cursorSizeOverflow(
                baseSize: baseSize.rawValue,
                scale: maximumScale
            )
        }

        return CursorScaleResolution(
            size: CursorSize(unchecked: Int32(scaledValue)),
            bufferScale: PositiveInt32(unchecked: maximumScale)
        )
    }
}

package enum CursorScalePolicyError: Error, Equatable, Sendable {
    case cursorSizeOverflow(baseSize: Int32, scale: Int32)
}
