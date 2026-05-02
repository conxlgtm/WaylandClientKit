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

        let effects = state.reduce(.unmanagedPointerEntered)

        #expect(state.focus == .unfocused)
        #expect(effects.isEmpty)
    }

    @Test
    func pointerLeaveForDifferentSurfaceKeepsFocus() {
        var state = PointerCursorSeatState()
        state.focus = .focused(surfaceID: 100, enterSerial: 77)

        let effects = state.reduce(.pointerLeft(surfaceID: 200))

        #expect(state.focus == .focused(surfaceID: 100, enterSerial: 77))
        #expect(effects.isEmpty)
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
        #expect(effects.count == 1)
        guard case .destroyCursorSurface(let destroyedSurface) = effects.first else {
            Issue.record("Expected destroyCursorSurface effect")
            return
        }
        #expect(destroyedSurface === surface)
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
