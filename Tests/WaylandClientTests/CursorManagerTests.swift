import Testing
import WaylandCursor
import WaylandRaw

@testable import WaylandClient

@Suite
struct CursorManagerTests {
    @Test
    func cursorConfigurationRejectsThemeNamesThatWouldTruncateAtCBoundary() throws {
        #expect(
            throws: CursorConfigurationError.themeNameContainsInteriorNUL
        ) {
            _ = try CursorConfiguration(themeName: "theme\0fallback")
        }
    }

    @Test
    func pointerEnterSetsDefaultCursorForRegisteredSurface() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())

        manager.register(surfaceID: 100)
        manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 1),
                surfaceID: 100,
                serial: 77
            ))
        let expectedSetRequest = SetCursorRequest(
            seatID: RawSeatID(rawValue: 1),
            serial: 77,
            surfaceID: 0xC00,
            hotspotX: 3,
            hotspotY: 4
        )

        #expect(backend.resolvedCursorNames == ["left_ptr"])
        #expect(backend.createdSurfaceSeatIDs == [RawSeatID(rawValue: 1)])
        #expect(backend.setCursorRequests == [expectedSetRequest])
        #expect(backend.createdSurfaces.first?.attachedCount == 1)
        #expect(backend.createdSurfaces.first?.commitCount == 1)
        #expect(
            manager.requestResults == [
                .set(seatID: SeatID(rawValue: 1), serial: 77, cursor: .defaultArrow)
            ])
    }

    @Test
    func pointerEnterForUnknownSurfaceDoesNotSetCursor() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())

        manager.register(surfaceID: 100)
        manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 1),
                surfaceID: 200,
                serial: 77
            ))

        #expect(backend.resolvedCursorNames.isEmpty)
        #expect(backend.createdSurfaces.isEmpty)
        #expect(backend.setCursorRequests.isEmpty)
        #expect(manager.requestResults.isEmpty)
    }

    @Test
    func hiddenCursorUsesNilSurface() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())

        manager.register(surfaceID: 100)
        try manager.setPointerCursor(.hidden)
        manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 2),
                surfaceID: 100,
                serial: 55
            ))
        let expectedSetRequest = SetCursorRequest(
            seatID: RawSeatID(rawValue: 2),
            serial: 55,
            surfaceID: nil,
            hotspotX: 0,
            hotspotY: 0
        )

        #expect(backend.createdSurfaces.isEmpty)
        #expect(backend.setCursorRequests == [expectedSetRequest])
        #expect(
            manager.requestResults == [
                .hidden(seatID: SeatID(rawValue: 2), serial: 55)
            ])
    }

    @Test
    func seatRemovalDestroysOnlyThatSeatCursorSurface() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())
        let seatA = RawSeatID(rawValue: 1)
        let seatB = RawSeatID(rawValue: 2)

        manager.register(surfaceID: 100)
        manager.register(surfaceID: 200)
        manager.observe(rawPointerEnter(sequence: 1, seatID: seatA, surfaceID: 100))
        manager.observe(rawPointerEnter(sequence: 2, seatID: seatB, surfaceID: 200))
        let firstSurface = try #require(backend.surface(for: seatA))
        let secondSurface = try #require(backend.surface(for: seatB))

        manager.observe(rawSeatRemoved(sequence: 3, seatID: seatA))

        #expect(firstSurface.destroyCount == 1)
        #expect(secondSurface.destroyCount == 0)
    }

    @Test
    func pointerCapabilityRemovalClearsOnlyThatSeatCursorState() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())
        let seatA = RawSeatID(rawValue: 1)
        let seatB = RawSeatID(rawValue: 2)

        manager.register(surfaceID: 100)
        manager.register(surfaceID: 200)
        manager.observe(rawPointerEnter(sequence: 1, seatID: seatA, surfaceID: 100))
        manager.observe(rawPointerEnter(sequence: 2, seatID: seatB, surfaceID: 200))
        let firstSurface = try #require(backend.surface(for: seatA))
        let secondSurface = try #require(backend.surface(for: seatB))
        backend.setCursorRequests.removeAll()

        manager.observe(rawSeatCapabilities(sequence: 3, seatID: seatA, activeCapabilities: []))
        try manager.setPointerCursor(.text)

        #expect(firstSurface.destroyCount == 1)
        #expect(secondSurface.destroyCount == 0)
        #expect(backend.setCursorRequests.map(\.seatID) == [seatB])
    }

    @Test
    func pointerLeaveClearsFocusWithoutDestroyingCursorSurface() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())
        let seatID = RawSeatID(rawValue: 1)

        manager.register(surfaceID: 100)
        manager.observe(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 100))
        let cursorSurface = try #require(backend.surface(for: seatID))
        backend.setCursorRequests.removeAll()

        manager.observe(rawPointerLeave(sequence: 2, seatID: seatID, surfaceID: 100))
        try manager.setPointerCursor(.text)

        #expect(cursorSurface.destroyCount == 0)
        #expect(backend.setCursorRequests.isEmpty)
    }

    @Test
    func unregisteringFocusedSurfaceClearsFocusWithoutDestroyingCursorSurface() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())
        let seatID = RawSeatID(rawValue: 1)

        manager.register(surfaceID: 100)
        manager.observe(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 100))
        let cursorSurface = try #require(backend.surface(for: seatID))
        backend.setCursorRequests.removeAll()

        manager.unregister(surfaceID: 100)
        try manager.setPointerCursor(.text)

        #expect(cursorSurface.destroyCount == 0)
        #expect(backend.setCursorRequests.isEmpty)
    }

    @Test
    func cursorChangeUpdatesOnlyFocusedSeats() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())
        let seatA = RawSeatID(rawValue: 1)
        let seatB = RawSeatID(rawValue: 2)
        let seatC = RawSeatID(rawValue: 3)

        manager.register(surfaceID: 100)
        manager.register(surfaceID: 300)
        manager.observe(rawPointerEnter(sequence: 1, seatID: seatA, surfaceID: 100))
        manager.observe(rawPointerEnter(sequence: 2, seatID: seatB, surfaceID: 200))
        manager.observe(rawPointerEnter(sequence: 3, seatID: seatC, surfaceID: 300))
        backend.resolvedCursorNames.removeAll()
        backend.setCursorRequests.removeAll()

        try manager.setPointerCursor(.text)

        #expect(backend.resolvedCursorNames == ["text"])
        #expect(backend.setCursorRequests.map(\.seatID) == [seatA, seatC])
    }

    @Test
    func missingDesiredCursorFallsBackToConfiguredCursor() throws {
        let backend = try RecordingCursorBackend()
        backend.missingCursorNames = ["text"]
        let manager = try CursorManager(backend: backend, configuration: .init())

        manager.register(surfaceID: 100)
        try manager.setPointerCursor(.text)
        manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 4),
                surfaceID: 100,
                serial: 88
            ))

        #expect(backend.resolvedCursorNames == ["text", "left_ptr"])
        #expect(
            manager.requestResults == [
                .set(seatID: SeatID(rawValue: 4), serial: 88, cursor: .defaultArrow)
            ])
    }

    @Test
    func cursorChangeValidatesBeforeChangingDesiredCursor() throws {
        let backend = try RecordingCursorBackend()
        backend.missingCursorNames = ["text", "left_ptr"]
        let manager = try CursorManager(backend: backend, configuration: .init())

        #expect(throws: CursorError.missingCursor("left_ptr")) {
            try manager.setPointerCursor(.text)
        }

        #expect(manager.pointerCursor == .defaultArrow)
        #expect(manager.requestResults.isEmpty)
    }

    @Test
    func explicitCursorRequestFailureIsTyped() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())
        let rawSeatID = RawSeatID(rawValue: 6)
        let seatID = SeatID(rawValue: 6)

        manager.register(surfaceID: 100)
        manager.observe(rawPointerEnter(sequence: 1, seatID: rawSeatID, surfaceID: 100))
        backend.setCursorResultOverride = .skippedNoPointer(rawSeatID)

        #expect(
            throws: ClientError.cursor(
                .requestFailed(
                    PointerCursorRequestFailure(
                        operation: .setNamed,
                        seatID: seatID,
                        requestedCursor: .text,
                        backendResult: .skippedNoPointer(seatID)
                    )
                )
            )
        ) {
            try manager.setPointerCursor(.text)
        }
    }

    @Test
    func automaticCursorFailureReturnsPublicDiagnostic() throws {
        let backend = try RecordingCursorBackend()
        backend.missingCursorNames = ["left_ptr"]
        let manager = try CursorManager(backend: backend, configuration: .init())

        manager.register(surfaceID: 100)
        let diagnostics = manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 5),
                surfaceID: 100,
                serial: 55
            ))

        #expect(manager.requestResults == [.skippedMissingCursor(name: "left_ptr")])
        let expectedDiagnostic = InputEvent(
            sequence: 1,
            seatID: SeatID(rawValue: 5),
            windowID: nil,
            kind: .diagnostic(
                InputDiagnostic(
                    operation: .cursor("missingCursor"),
                    message: "cursor left_ptr is unavailable"
                )
            )
        )

        #expect(diagnostics == [expectedDiagnostic])
    }
}

private struct SetCursorRequest: Equatable {
    let seatID: RawSeatID
    let serial: UInt32
    let surfaceID: RawObjectID?
    let hotspotX: Int32
    let hotspotY: Int32
}

private final class RecordingCursorBackend: CursorManagerBackend {
    var resolvedCursorNames: [String] = []
    var createdSurfaceSeatIDs: [RawSeatID] = []
    var createdSurfaces: [RecordingCursorSurface] = []
    var setCursorRequests: [SetCursorRequest] = []
    var missingCursorNames: Set<String> = []
    var setCursorResultOverride: RawPointerCursorResult?

    private let image: CursorImage
    private var nextSurfaceID = UInt32(0xC00)

    init() throws {
        image = try CursorImage(
            width: 16,
            height: 24,
            hotspotX: 3,
            hotspotY: 4,
            delay: 0,
            buffer: RawBorrowedBuffer(pointer: try #require(OpaquePointer(bitPattern: 0xB00)))
        )
    }

    func preconditionIsOwnerThread() {
        // Test backend is always used on the test thread.
    }

    func cursorImage(named name: String) throws -> CursorImage {
        resolvedCursorNames.append(name)

        if missingCursorNames.contains(name) {
            throw CursorError.missingCursor(name)
        }

        return image
    }

    func createCursorSurface(for seatID: RawSeatID) throws -> CursorManagerSurface {
        createdSurfaceSeatIDs.append(seatID)
        let surface = RecordingCursorSurface(objectID: RawObjectID(nextSurfaceID))
        nextSurfaceID += 1
        createdSurfaces.append(surface)
        return surface
    }

    func setPointerCursor(
        seatID: RawSeatID,
        serial: UInt32,
        surface: CursorManagerSurface?,
        hotspotX: Int32,
        hotspotY: Int32
    ) -> RawPointerCursorResult {
        setCursorRequests.append(
            SetCursorRequest(
                seatID: seatID,
                serial: serial,
                surfaceID: surface?.objectID,
                hotspotX: hotspotX,
                hotspotY: hotspotY
            )
        )

        if let setCursorResultOverride {
            return setCursorResultOverride
        }

        return .set(
            RawPointerCursorSetResult(
                seatID: seatID,
                serial: serial,
                surfaceID: surface?.objectID,
                hotspotX: hotspotX,
                hotspotY: hotspotY
            )
        )
    }

    func surface(for seatID: RawSeatID) -> RecordingCursorSurface? {
        guard let index = createdSurfaceSeatIDs.firstIndex(of: seatID) else {
            return nil
        }

        return createdSurfaces[index]
    }
}

private final class RecordingCursorSurface: CursorManagerSurface {
    let objectID: RawObjectID?
    private(set) var attachedCount = 0
    private(set) var commitCount = 0
    private(set) var destroyCount = 0

    init(objectID cursorSurfaceID: RawObjectID) {
        objectID = cursorSurfaceID
    }

    func attach(_: CursorImage) {
        attachedCount += 1
    }

    func commit() {
        commitCount += 1
    }

    func destroy() {
        destroyCount += 1
    }
}

private func rawSeatRemoved(sequence: UInt64, seatID: RawSeatID) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .seatRemoved
    )
}

private func rawSeatCapabilities(
    sequence: UInt64,
    seatID: RawSeatID,
    activeCapabilities: WaylandRaw.SeatCapabilities
) -> RawInputEvent {
    rawEvent(
        sequence: sequence,
        seatID: seatID,
        kind: .seat(
            RawSeatEventSnapshot(
                advertisedCapabilities: activeCapabilities,
                activeCapabilities: activeCapabilities,
                name: nil
            )
        )
    )
}
