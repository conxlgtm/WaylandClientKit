import WaylandRaw

package struct CursorOutputScale: Equatable, Sendable {
    package let outputID: OutputID
    package let scale: PositiveInt32

    package init(outputID cursorOutputID: OutputID, scale cursorOutputScale: PositiveInt32) {
        outputID = cursorOutputID
        scale = cursorOutputScale
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

package enum CursorScalePolicy: Equatable, Sendable {
    case fixed(CursorSize)
    case matchFocusedSurface
    case maximumOutputScale

    package func cursorSize(
        in context: CursorScaleContext
    ) throws(CursorScalePolicyError) -> CursorSize {
        switch self {
        case .fixed(let size):
            size
        case .matchFocusedSurface:
            try scaledSize(
                baseSize: context.baseSize,
                outputs: context.focusedOutputs
            )
        case .maximumOutputScale:
            try scaledSize(
                baseSize: context.baseSize,
                outputs: context.availableOutputs
            )
        }
    }

    private func scaledSize(
        baseSize: CursorSize,
        outputs: [CursorOutputScale]
    ) throws(CursorScalePolicyError) -> CursorSize {
        guard let maximumScale = outputs.map(\.scale.rawValue).max() else {
            return baseSize
        }

        let scaledValue = Int64(baseSize.rawValue) * Int64(maximumScale)
        guard scaledValue <= Int64(Int32.max) else {
            throw .cursorSizeOverflow(
                baseSize: baseSize.rawValue,
                scale: maximumScale
            )
        }

        return CursorSize(unchecked: Int32(scaledValue))
    }
}

package enum CursorScalePolicyError: Error, Equatable, Sendable {
    case cursorSizeOverflow(baseSize: Int32, scale: Int32)
}
