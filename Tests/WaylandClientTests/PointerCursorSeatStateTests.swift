import Testing
import WaylandCursor
import WaylandRaw

@testable import WaylandClient

@Suite
struct PointerCursorSeatStateTests {
    @Test
    func managedPointerEnterSetsFocusAndCarriesApplyCursorEffect() {
        let sourceEvent = rawPointerEnter(
            sequence: 1,
            seatID: RawSeatID(rawValue: 1),
            surfaceID: 100,
            serial: 77
        )
        var state = PointerCursorSeatState()

        let effects = state.reduce(
            .managedPointerEntered(
                surfaceID: 100,
                serial: 77,
                sourceEvent: sourceEvent
            ))

        #expect(state.focus == .focused(surfaceID: 100, enterSerial: 77))
        #expect(effects.count == 1)
        guard case .applyCursor(let serial, let effectSourceEvent) = effects.first else {
            Issue.record("Expected applyCursor effect")
            return
        }
        #expect(serial == 77)
        #expect(effectSourceEvent == sourceEvent)
    }

    @Test
    func unmanagedPointerEnterClearsFocusWithoutEffects() {
        var state = PointerCursorSeatState()
        state.focus = .focused(surfaceID: 100, enterSerial: 77)
        state.markApplied(.hidden(serial: 77))

        let effects = state.reduce(.unmanagedPointerEntered)

        #expect(state.focus == .unfocused)
        #expect(state.application == .unapplied)
        #expect(effects.isEmpty)
    }

    @Test
    func pointerLeaveForDifferentSurfaceKeepsFocus() {
        var state = PointerCursorSeatState()
        state.focus = .focused(surfaceID: 100, enterSerial: 77)
        state.markApplied(.hidden(serial: 77))

        let effects = state.reduce(.pointerLeft(surfaceID: 200))

        #expect(state.focus == .focused(surfaceID: 100, enterSerial: 77))
        #expect(state.application == .hidden(serial: 77))
        #expect(effects.isEmpty)
    }

    @Test
    func pointerLeaveForFocusedSurfaceClearsAppliedCursor() {
        var state = PointerCursorSeatState()
        state.focus = .focused(surfaceID: 100, enterSerial: 77)
        state.markApplied(.named(cursor: .text, serial: 77, surfaceID: 0xC00))

        let effects = state.reduce(.pointerLeft(surfaceID: 100))

        #expect(state.focus == .unfocused)
        #expect(state.application == .unapplied)
        #expect(effects.isEmpty)
    }

    @Test
    func managedPointerEnterResetsAppliedCursorUntilApplyCompletes() {
        let sourceEvent = rawPointerEnter(
            sequence: 1,
            seatID: RawSeatID(rawValue: 1),
            surfaceID: 200,
            serial: 88
        )
        var state = PointerCursorSeatState()
        state.focus = .focused(surfaceID: 100, enterSerial: 77)
        state.markApplied(.named(cursor: .text, serial: 77, surfaceID: 0xC00))

        let effects = state.reduce(
            .managedPointerEntered(
                surfaceID: 200,
                serial: 88,
                sourceEvent: sourceEvent
            ))

        #expect(state.focus == .focused(surfaceID: 200, enterSerial: 88))
        #expect(state.application == .unapplied)
        #expect(effects.count == 1)
    }

    @Test
    func pointerUnavailableDestroysCursorSurfaceAndClearsState() {
        let surface = ReducerCursorSurface()
        var state = PointerCursorSeatState()
        state.focus = .focused(surfaceID: 100, enterSerial: 77)
        state.cursorSurface = surface

        let effects = state.reduce(.pointerUnavailable)

        #expect(state.focus == .unfocused)
        #expect(state.cursorSurface == nil)
        #expect(state.application == .unapplied)
        #expect(effects.count == 1)
        guard case .destroyCursorSurface(let destroyedSurface) = effects.first else {
            Issue.record("Expected destroyCursorSurface effect")
            return
        }
        #expect(destroyedSurface === surface)
    }

    @Test
    func desiredPointerCursorStateKeepsHiddenCursorUnresolved() throws {
        let image = try CursorImage(
            width: 16,
            height: 24,
            hotspotX: 3,
            hotspotY: 4,
            delay: 0,
            buffer: RawBorrowedBuffer(pointer: try #require(OpaquePointer(bitPattern: 0xB00)))
        )

        let state = DesiredPointerCursorState(
            cursor: .hidden,
            resolved: ResolvedPointerCursorImage(cursor: .text, image: image)
        )

        #expect(state.cursor == .hidden)
        #expect(state.resolvedImage == nil)
    }

    @Test
    func desiredPointerCursorStateCachesUnavailableResolution() {
        var state = DesiredPointerCursorState(cursor: .defaultArrow)

        state.cacheUnavailable(.missingCursor(name: "left_ptr"))

        #expect(state.cursor == .defaultArrow)
        #expect(state.resolvedImage == nil)
        #expect(state.unavailableDiagnostic == .missingCursor(name: "left_ptr"))
    }
}

private final class ReducerCursorSurface: CursorManagerSurface {
    let objectID: RawObjectID? = 0xC00

    func attach(_: CursorImage) {
        // Reducer tests only need object identity.
    }

    func commit() {
        // Reducer tests only need object identity.
    }

    func destroy() {
        // Reducer tests only need object identity.
    }
}
