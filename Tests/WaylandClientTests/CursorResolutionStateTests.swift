import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct CursorResolutionStateTests {
    @Test
    func automaticCursorFailureIsCachedAcrossPointerEnters() throws {
        let backend = try RecordingCursorBackend()
        backend.missingCursorNames = ["left_ptr"]
        let manager = try CursorManager(backend: backend, configuration: .init())

        manager.register(surfaceID: 100)
        manager.register(surfaceID: 200)
        let firstDiagnostics = manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 5),
                surfaceID: 100,
                serial: 55
            ))
        let secondDiagnostics = manager.observe(
            rawPointerEnter(
                sequence: 2,
                seatID: RawSeatID(rawValue: 5),
                surfaceID: 200,
                serial: 56
            ))

        #expect(backend.resolvedCursorNames == ["left_ptr"])
        #expect(
            manager.requestResults == [
                .skippedMissingCursor(name: "left_ptr"),
                .skippedMissingCursor(name: "left_ptr"),
            ])
        #expect(firstDiagnostics.first?.kind == cursorMissingDiagnostic())
        #expect(secondDiagnostics.first?.kind == cursorMissingDiagnostic())
    }

    @Test
    func explicitCursorChangeClearsCachedAutomaticFailure() throws {
        let backend = try RecordingCursorBackend()
        backend.missingCursorNames = ["left_ptr"]
        let manager = try CursorManager(backend: backend, configuration: .init())

        manager.register(surfaceID: 100)
        _ = manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 5),
                surfaceID: 100,
                serial: 55
            ))
        backend.missingCursorNames.removeAll()
        _ = try manager.setPointerCursor(.text)

        #expect(backend.resolvedCursorNames == ["left_ptr", "text"])
        #expect(
            manager.requestResults == [
                .skippedMissingCursor(name: "left_ptr"),
                .set(seatID: SeatID(rawValue: 5), serial: 55, cursor: .text),
            ])
    }
}

private func cursorMissingDiagnostic() -> InputEventKind {
    .diagnostic(
        InputDiagnostic(
            .cursor(.missingCursor(name: "left_ptr"))
        )
    )
}
