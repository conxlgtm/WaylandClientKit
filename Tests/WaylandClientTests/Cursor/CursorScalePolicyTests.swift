import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct CursorScalePolicyTests {
    @Test
    func fixedPolicyIgnoresOutputScale() throws {
        let context = try cursorScaleContext(
            focusedOutputs: [outputScale(id: 1, scale: 2)],
            availableOutputs: [outputScale(id: 1, scale: 2)]
        )

        let size = try CursorScalePolicy.fixed(CursorSize(unchecked: 48))
            .cursorSize(in: context)

        #expect(size == CursorSize(unchecked: 48))
    }

    @Test
    func focusedSurfacePolicyUsesMaximumFocusedOutputScale() throws {
        let context = try cursorScaleContext(
            focusedOutputs: [
                outputScale(id: 1, scale: 1),
                outputScale(id: 2, scale: 3),
            ],
            availableOutputs: [
                outputScale(id: 1, scale: 1),
                outputScale(id: 2, scale: 3),
                outputScale(id: 3, scale: 4),
            ]
        )

        let size = try CursorScalePolicy.matchFocusedSurface.cursorSize(in: context)

        #expect(size == CursorSize(unchecked: 72))
    }

    @Test
    func maximumOutputPolicyUsesAllKnownOutputs() throws {
        let context = try cursorScaleContext(
            focusedOutputs: [outputScale(id: 1, scale: 2)],
            availableOutputs: [
                outputScale(id: 1, scale: 2),
                outputScale(id: 2, scale: 4),
            ]
        )

        let size = try CursorScalePolicy.maximumOutputScale.cursorSize(in: context)

        #expect(size == CursorSize(unchecked: 96))
    }

    @Test
    func scalePolicyFallsBackToBaseSizeWhenNoOutputsAreKnown() throws {
        let context = try cursorScaleContext(
            focusedOutputs: [],
            availableOutputs: []
        )

        #expect(
            try CursorScalePolicy.matchFocusedSurface.cursorSize(in: context)
                == CursorSize(unchecked: 24)
        )
        #expect(
            try CursorScalePolicy.maximumOutputScale.cursorSize(in: context)
                == CursorSize(unchecked: 24)
        )
    }

    @Test
    func focusedSurfacePolicyFallsBackAfterFocusedOutputsAreRemoved() throws {
        let context = try cursorScaleContext(
            focusedOutputs: [],
            availableOutputs: [outputScale(id: 1, scale: 4)]
        )

        #expect(
            try CursorScalePolicy.matchFocusedSurface.cursorSize(in: context)
                == CursorSize(unchecked: 24)
        )
    }

    @Test
    func policyResultChangesWhenOutputScaleChanges() throws {
        let lowScaleContext = try cursorScaleContext(
            focusedOutputs: [outputScale(id: 1, scale: 1)],
            availableOutputs: [outputScale(id: 1, scale: 1)]
        )
        let highScaleContext = try cursorScaleContext(
            focusedOutputs: [outputScale(id: 1, scale: 3)],
            availableOutputs: [outputScale(id: 1, scale: 3)]
        )

        #expect(
            try CursorScalePolicy.matchFocusedSurface.cursorSize(in: lowScaleContext)
                == CursorSize(unchecked: 24)
        )
        #expect(
            try CursorScalePolicy.matchFocusedSurface.cursorSize(in: highScaleContext)
                == CursorSize(unchecked: 72)
        )
    }

    @Test
    func scalePolicyRejectsCursorSizeOverflow() throws {
        let context = try cursorScaleContext(
            focusedOutputs: [outputScale(id: 1, scale: 2)],
            availableOutputs: [outputScale(id: 1, scale: 2)],
            baseSize: CursorSize(unchecked: Int32.max)
        )

        #expect(
            throws: CursorScalePolicyError.cursorSizeOverflow(
                baseSize: Int32.max,
                scale: 2
            )
        ) {
            _ = try CursorScalePolicy.matchFocusedSurface.cursorSize(in: context)
        }
    }
}

private func cursorScaleContext(
    focusedOutputs: [CursorOutputScale],
    availableOutputs: [CursorOutputScale],
    baseSize: CursorSize = CursorSize(unchecked: 24)
) throws -> CursorScaleContext {
    CursorScaleContext(
        seatID: SeatID(rawValue: 1),
        focusedSurfaceID: RawObjectID(0xC00),
        focusedOutputs: focusedOutputs,
        availableOutputs: availableOutputs,
        baseSize: baseSize
    )
}

private func outputScale(id: UInt32, scale: Int32) throws -> CursorOutputScale {
    try CursorOutputScale(
        outputID: OutputID(rawValue: id),
        scale: PositiveInt32(scale)
    )
}
