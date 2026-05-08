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
        #expect(backend.setCursorRequests.isEmpty)
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
        let results = try manager.setPointerCursor(.text)

        #expect(backend.resolvedCursorNames == ["left_ptr", "text"])
        #expect(
            results == [
                .set(seatID: SeatID(rawValue: 5), serial: 55, cursor: .text)
            ])
    }

    @Test
    func automaticCursorBackendFailureDoesNotPoisonFuturePointerEnters() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())
        let seatID = RawSeatID(rawValue: 6)

        manager.register(surfaceID: 100)
        backend.setCursorResultOverride = .skippedUnknownSeat(seatID)
        let firstDiagnostics = manager.observe(
            rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 100, serial: 61)
        )
        backend.setCursorResultOverride = nil
        let secondDiagnostics = manager.observe(
            rawPointerEnter(sequence: 2, seatID: seatID, surfaceID: 100, serial: 62)
        )

        #expect(
            automaticCursorFailure(firstDiagnostics)
                == .cursorRequest(
                    PointerCursorRequestFailure(
                        seatID: SeatID(rawValue: seatID.rawValue),
                        requestedCursor: .defaultArrow,
                        backendResult: .skippedUnknownSeat
                    )
                )
        )
        #expect(secondDiagnostics.isEmpty)
        #expect(backend.resolvedCursorNames == ["left_ptr"])
        #expect(backend.setCursorRequests.map(\.serial) == [61, 62])
    }

    @Test
    func automaticCursorSurfaceCreationFailureIsRetried() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())
        let seatID = RawSeatID(rawValue: 7)

        manager.register(surfaceID: 100)
        backend.cursorSurfaceCreationError = CursorSurfaceCreationError.transient
        let firstDiagnostics = manager.observe(
            rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 100, serial: 71)
        )
        let secondDiagnostics = manager.observe(
            rawPointerEnter(sequence: 2, seatID: seatID, surfaceID: 100, serial: 72)
        )

        #expect(automaticCursorFailure(firstDiagnostics) == .cursorSurfaceCreation("transient"))
        #expect(secondDiagnostics.isEmpty)
        #expect(backend.cursorSurfaceRequestSeatIDs == [seatID, seatID])
        #expect(backend.setCursorRequests.map(\.serial) == [72])
    }
}

private func cursorMissingDiagnostic() -> InputEventKind {
    .diagnostic(
        InputDiagnostic(
            .cursor(.missingCursor(name: "left_ptr"))
        )
    )
}

private func automaticCursorFailure(_ events: [InputEvent]) -> AutomaticPointerEnterFailure? {
    guard let firstEvent = events.first,
        case .diagnostic(let diagnostic) = firstEvent.kind,
        case .cursor(.automaticPointerEnterFailed(let failure)) = diagnostic.payload
    else {
        return nil
    }

    return failure
}

private enum CursorSurfaceCreationError: Error {
    case transient
}
