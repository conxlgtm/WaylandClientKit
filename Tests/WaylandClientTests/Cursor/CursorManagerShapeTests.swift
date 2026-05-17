import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct CursorManagerShapeTests {
    @Test
    func cursorShapeRequestUsesCompositorShapeWithoutThemeSurface() throws {
        let backend = try RecordingCursorBackend()
        backend.cursorShapeSupported = true
        let manager = try CursorManager(backend: backend, configuration: .init())

        manager.register(surfaceID: 100)
        manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 2),
                surfaceID: 100,
                serial: 55
            ))

        #expect(backend.resolvedCursorNames.isEmpty)
        #expect(backend.createdSurfaces.isEmpty)
        #expect(
            backend.setCursorShapeRequests == [
                SetCursorShapeRequest(
                    seatID: RawSeatID(rawValue: 2),
                    serial: 55,
                    shape: .default
                )
            ]
        )
        #expect(backend.setCursorRequests.isEmpty)
    }

    @Test
    func unmappedCursorFallsBackToThemeSurfaceWhenCursorShapeIsSupported() throws {
        let backend = try RecordingCursorBackend()
        backend.cursorShapeSupported = true
        let manager = try CursorManager(backend: backend, configuration: .init())
        let customCursor = try PointerCursor(name: "custom-theme-name")

        manager.register(surfaceID: 100)
        try manager.setPointerCursor(customCursor)
        manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 2),
                surfaceID: 100,
                serial: 55
            ))

        #expect(backend.resolvedCursorNames == ["custom-theme-name"])
        #expect(backend.createdSurfaces.count == 1)
        #expect(backend.setCursorRequests.map(\.serial) == [55])
        #expect(backend.setCursorShapeRequests.isEmpty)
    }
}
