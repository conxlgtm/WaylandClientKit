// swiftlint:disable file_length

import Testing
import WaylandCursor
import WaylandRaw

@testable import WaylandClient

@Suite
struct CursorManagerTests {  // swiftlint:disable:this type_body_length
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
    }

    @Test
    func matchFocusedOutputPolicyUsesFocusedSurfaceScale() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(
            backend: backend,
            configuration: CursorConfiguration(scalePolicy: .matchFocusedOutput)
        )

        manager.register(surfaceID: 100)
        try manager.updateOutputScales(
            for: 100,
            focusedOutputs: [cursorOutputScale(id: 1, scale: 2)],
            availableOutputs: [
                cursorOutputScale(id: 1, scale: 2),
                cursorOutputScale(id: 2, scale: 3),
            ]
        )
        manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 1),
                surfaceID: 100,
                serial: 77
            ))

        #expect(backend.resolvedCursorSizes == [CursorSize(unchecked: 48)])
    }

    @Test
    func scaledAutomaticThemeCursorUsesBufferScaleAndLogicalHotspot() throws {
        let backend = try RecordingCursorBackend()
        let scaledSize = CursorSize(unchecked: 48)
        backend.cursorImagesBySize[scaledSize] = try makeCursorImage(
            width: 48,
            height: 48,
            hotspotX: 6,
            hotspotY: 8
        )
        let manager = try CursorManager(
            backend: backend,
            configuration: CursorConfiguration(scalePolicy: .matchFocusedOutput)
        )

        manager.register(surfaceID: 100)
        try manager.updateOutputScales(
            for: 100,
            focusedOutputs: [cursorOutputScale(id: 1, scale: 2)],
            availableOutputs: [cursorOutputScale(id: 1, scale: 2)]
        )
        manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 1),
                surfaceID: 100,
                serial: 77
            ))

        let surface = try #require(backend.surface(for: RawSeatID(rawValue: 1)))
        #expect(surface.bufferScaleRequests == [2])
        #expect(surface.operationLog == [.setBufferScale(2), .attach, .commit])
        #expect(backend.resolvedCursorSizes == [scaledSize])
        #expect(
            backend.setCursorRequests == [
                SetCursorRequest(
                    seatID: RawSeatID(rawValue: 1),
                    serial: 77,
                    surfaceID: 0xC00,
                    hotspotX: 3,
                    hotspotY: 4
                )
            ])
    }

    @Test
    func scaledExplicitThemeCursorUsesBufferScaleAndLogicalHotspot() throws {
        let backend = try RecordingCursorBackend()
        let scaledSize = CursorSize(unchecked: 48)
        backend.cursorImagesBySize[scaledSize] = try makeCursorImage(
            width: 48,
            height: 48,
            hotspotX: 10,
            hotspotY: 12
        )
        let manager = try CursorManager(
            backend: backend,
            configuration: CursorConfiguration(scalePolicy: .maximumOutputScale)
        )

        manager.register(surfaceID: 100)
        try manager.updateOutputScales(
            for: 100,
            focusedOutputs: [cursorOutputScale(id: 1, scale: 1)],
            availableOutputs: [
                cursorOutputScale(id: 1, scale: 1),
                cursorOutputScale(id: 2, scale: 2),
            ]
        )
        manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 1),
                surfaceID: 100,
                serial: 77
            ))
        backend.setCursorRequests.removeAll()

        try manager.setPointerCursor(.text)

        let surface = try #require(backend.surface(for: RawSeatID(rawValue: 1)))
        #expect(surface.bufferScaleRequests == [2, 2])
        #expect(
            surface.operationLog == [
                .setBufferScale(2),
                .attach,
                .commit,
                .setBufferScale(2),
                .attach,
                .commit,
            ])
        #expect(
            backend.setCursorRequests == [
                SetCursorRequest(
                    seatID: RawSeatID(rawValue: 1),
                    serial: 77,
                    surfaceID: 0xC00,
                    hotspotX: 5,
                    hotspotY: 6
                )
            ])
    }

    @Test
    func scaledThemeCursorHotspotUsesIntegerSurfaceCoordinates() throws {
        let backend = try RecordingCursorBackend()
        let scaledSize = CursorSize(unchecked: 48)
        backend.cursorImagesBySize[scaledSize] = try makeCursorImage(
            width: 48,
            height: 48,
            hotspotX: 7,
            hotspotY: 9
        )
        let manager = try CursorManager(
            backend: backend,
            configuration: CursorConfiguration(scalePolicy: .matchFocusedOutput)
        )

        manager.register(surfaceID: 100)
        try manager.updateOutputScales(
            for: 100,
            focusedOutputs: [cursorOutputScale(id: 1, scale: 2)],
            availableOutputs: [cursorOutputScale(id: 1, scale: 2)]
        )
        manager.observe(
            rawPointerEnter(
                sequence: 1,
                seatID: RawSeatID(rawValue: 1),
                surfaceID: 100,
                serial: 77
            ))

        #expect(
            backend.setCursorRequests == [
                SetCursorRequest(
                    seatID: RawSeatID(rawValue: 1),
                    serial: 77,
                    surfaceID: 0xC00,
                    hotspotX: 3,
                    hotspotY: 4
                )
            ])
    }

    @Test
    func cursorOutputScaleChangeReappliesFocusedThemeCursor() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(
            backend: backend,
            configuration: CursorConfiguration(scalePolicy: .matchFocusedOutput)
        )

        manager.register(surfaceID: 100)
        manager.observe(
            rawPointerEnter(sequence: 1, seatID: RawSeatID(rawValue: 1), surfaceID: 100))

        try manager.updateOutputScales(
            for: 100,
            focusedOutputs: [cursorOutputScale(id: 1, scale: 3)],
            availableOutputs: [cursorOutputScale(id: 1, scale: 3)]
        )

        #expect(
            backend.resolvedCursorSizes == [
                CursorSize(unchecked: 24),
                CursorSize(unchecked: 72),
            ])
        #expect(backend.setCursorRequests.count == 2)
    }

    @Test
    func outputScaleChangeRecomputesFocusedCursorScale() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(
            backend: backend,
            configuration: CursorConfiguration(scalePolicy: .matchFocusedOutput)
        )

        manager.register(surfaceID: 100)
        try manager.updateOutputScales(
            for: 100,
            focusedOutputs: [cursorOutputScale(id: 1, scale: 1)],
            availableOutputs: [cursorOutputScale(id: 1, scale: 1)]
        )
        manager.observe(
            rawPointerEnter(sequence: 1, seatID: RawSeatID(rawValue: 1), surfaceID: 100))

        try manager.updateAvailableOutputScales([cursorOutputScale(id: 1, scale: 3)])

        #expect(
            backend.resolvedCursorSizes == [
                CursorSize(unchecked: 24),
                CursorSize(unchecked: 72),
            ])
        #expect(backend.setCursorRequests.count == 2)
    }

    @Test
    func outputScaleChangeRecomputesMaximumCursorScale() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(
            backend: backend,
            configuration: CursorConfiguration(scalePolicy: .maximumOutputScale)
        )

        manager.register(surfaceID: 100)
        try manager.updateOutputScales(
            for: 100,
            focusedOutputs: [cursorOutputScale(id: 1, scale: 1)],
            availableOutputs: [
                cursorOutputScale(id: 1, scale: 1),
                cursorOutputScale(id: 2, scale: 2),
            ]
        )
        manager.observe(
            rawPointerEnter(sequence: 1, seatID: RawSeatID(rawValue: 1), surfaceID: 100))

        try manager.updateAvailableOutputScales([
            cursorOutputScale(id: 1, scale: 1),
            cursorOutputScale(id: 2, scale: 4),
        ])

        #expect(
            backend.resolvedCursorSizes == [
                CursorSize(unchecked: 48),
                CursorSize(unchecked: 96),
            ])
        #expect(backend.setCursorRequests.count == 2)
    }

    @Test
    func maximumOutputScalePolicyUsesLargestKnownOutput() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(
            backend: backend,
            configuration: CursorConfiguration(scalePolicy: .maximumOutputScale)
        )

        manager.register(surfaceID: 100)
        try manager.updateOutputScales(
            for: 100,
            focusedOutputs: [cursorOutputScale(id: 1, scale: 1)],
            availableOutputs: [
                cursorOutputScale(id: 1, scale: 1),
                cursorOutputScale(id: 2, scale: 4),
            ]
        )
        manager.observe(
            rawPointerEnter(sequence: 1, seatID: RawSeatID(rawValue: 1), surfaceID: 100))

        #expect(backend.resolvedCursorSizes == [CursorSize(unchecked: 96)])
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
        #expect(Array(firstSurface.operationLog.suffix(3)) == [.detach, .commit, .destroy])
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
        #expect(Array(firstSurface.operationLog.suffix(3)) == [.detach, .commit, .destroy])
        #expect(secondSurface.destroyCount == 0)
        #expect(backend.setCursorRequests.map(\.seatID) == [seatB])
    }

    @Test
    func shutdownDetachesCommitsAndDestroysCursorSurfaces() throws {
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

        manager.shutdown()

        #expect(
            firstSurface.operationLog == [
                .setBufferScale(1),
                .attach,
                .commit,
                .detach,
                .commit,
                .destroy,
            ])
        #expect(
            secondSurface.operationLog == [
                .setBufferScale(1),
                .attach,
                .commit,
                .detach,
                .commit,
                .destroy,
            ])
    }

    @Test
    func shutdownIsIdempotentAndIgnoresLaterInput() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())
        let seatID = RawSeatID(rawValue: 1)

        manager.register(surfaceID: 100)
        manager.observe(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 100))
        let cursorSurface = try #require(backend.surface(for: seatID))

        manager.shutdown()
        manager.shutdown()
        manager.register(surfaceID: 200)
        let diagnostics = manager.observe(
            rawPointerEnter(sequence: 2, seatID: seatID, surfaceID: 200))
        let requestResults = try manager.setPointerCursor(.text)

        #expect(
            cursorSurface.operationLog == [
                .setBufferScale(1),
                .attach,
                .commit,
                .detach,
                .commit,
                .destroy,
            ])
        #expect(diagnostics.isEmpty)
        #expect(requestResults.isEmpty)
        #expect(backend.createdSurfaces.count == 1)
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
        #expect(backend.setCursorRequests.map(\.serial) == [88])
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
        #expect(backend.setCursorRequests.isEmpty)
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

        #expect(backend.setCursorRequests.isEmpty)
        let expectedDiagnostic = InputEvent(
            sequence: 1,
            seatID: SeatID(rawValue: 5),
            target: .display,
            kind: .diagnostic(
                InputDiagnostic(
                    .cursor(.missingCursor(name: "left_ptr"))
                )
            )
        )

        #expect(diagnostics == [expectedDiagnostic])
    }
}

@Suite
struct CursorManagerFailureTests {
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
                        seatID: seatID,
                        requestedCursor: .text,
                        backendResult: .skippedNoPointer
                    )
                )
            )
        ) {
            try manager.setPointerCursor(.text)
        }
    }

    @Test
    func hiddenCursorRequestFailureIsTyped() throws {
        let backend = try RecordingCursorBackend()
        let manager = try CursorManager(backend: backend, configuration: .init())
        let rawSeatID = RawSeatID(rawValue: 7)
        let seatID = SeatID(rawValue: 7)

        manager.register(surfaceID: 100)
        manager.observe(rawPointerEnter(sequence: 1, seatID: rawSeatID, surfaceID: 100))
        backend.setCursorResultOverride = .skippedUnknownSeat(rawSeatID)

        #expect(
            throws: ClientError.cursor(
                .requestFailed(
                    PointerCursorRequestFailure(
                        seatID: seatID,
                        requestedCursor: .hidden,
                        backendResult: .skippedUnknownSeat
                    )
                )
            )
        ) {
            try manager.setPointerCursor(.hidden)
        }
    }
}

struct SetCursorRequest: Equatable {
    let seatID: RawSeatID
    let serial: UInt32
    let surfaceID: RawObjectID?
    let hotspotX: Int32
    let hotspotY: Int32
}

struct SetCursorShapeRequest: Equatable {
    let seatID: RawSeatID
    let serial: UInt32
    let shape: RawCursorShapeName
}

final class RecordingCursorBackend: CursorManagerBackend {
    var cursorShapeSupported = false
    var resolvedCursorNames: [String] = []
    var resolvedCursorSizes: [CursorSize] = []
    var cursorImagesBySize: [CursorSize: CursorImage] = [:]
    var createdSurfaceSeatIDs: [RawSeatID] = []
    var cursorSurfaceRequestSeatIDs: [RawSeatID] = []
    var createdSurfaces: [RecordingCursorSurface] = []
    var setCursorRequests: [SetCursorRequest] = []
    var setCursorShapeRequests: [SetCursorShapeRequest] = []
    var missingCursorNames: Set<String> = []
    var setCursorResultOverride: RawPointerCursorResult?
    var cursorSurfaceCreationError: (any Error)?

    private let image: CursorImage
    private var nextSurfaceID = UInt32(0xC00)

    init() throws {
        image = try makeCursorImage(
            width: 16,
            height: 24,
            hotspotX: 3,
            hotspotY: 4
        )
    }

    func preconditionIsOwnerThread() {
        // Test backend is always used on the test thread.
    }

    var supportsCursorShape: Bool {
        cursorShapeSupported
    }

    func cursorImage(named name: String, size: CursorSize) throws -> CursorImage {
        resolvedCursorNames.append(name)
        resolvedCursorSizes.append(size)

        if missingCursorNames.contains(name) {
            throw CursorError.missingCursor(name)
        }

        return cursorImagesBySize[size] ?? image
    }

    func createCursorSurface(for seatID: RawSeatID) throws -> CursorManagerSurface {
        cursorSurfaceRequestSeatIDs.append(seatID)
        if let error = cursorSurfaceCreationError {
            cursorSurfaceCreationError = nil
            throw error
        }

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

    func setPointerCursorShape(
        seatID: RawSeatID,
        serial: UInt32,
        shape: RawCursorShapeName
    ) throws -> RawPointerCursorResult {
        setCursorShapeRequests.append(
            SetCursorShapeRequest(seatID: seatID, serial: serial, shape: shape)
        )

        if let setCursorResultOverride {
            return setCursorResultOverride
        }

        return .set(
            RawPointerCursorSetResult(
                seatID: seatID,
                serial: serial,
                surfaceID: nil,
                hotspotX: 0,
                hotspotY: 0
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

final class RecordingCursorSurface: CursorManagerSurface {
    let objectID: RawObjectID?
    private(set) var attachedCount = 0
    private(set) var detachCount = 0
    private(set) var commitCount = 0
    private(set) var destroyCount = 0
    private(set) var bufferScaleRequests: [Int32] = []
    private(set) var operationLog: [CursorSurfaceOperation] = []

    init(objectID cursorSurfaceID: RawObjectID) {
        objectID = cursorSurfaceID
    }

    func setBufferScale(_ scale: Int32) {
        bufferScaleRequests.append(scale)
        operationLog.append(.setBufferScale(scale))
    }

    func attach(_: CursorImage) {
        attachedCount += 1
        operationLog.append(.attach)
    }

    func detach() {
        detachCount += 1
        operationLog.append(.detach)
    }

    func commit() {
        commitCount += 1
        operationLog.append(.commit)
    }

    func destroy() {
        destroyCount += 1
        operationLog.append(.destroy)
    }
}

enum CursorSurfaceOperation: Equatable {
    case setBufferScale(Int32)
    case attach
    case detach
    case commit
    case destroy
}

private func cursorOutputScale(id: UInt32, scale: Int32) throws -> CursorOutputScale {
    try CursorOutputScale(
        outputID: OutputID(rawValue: id),
        scale: PositiveInt32(scale)
    )
}

private func makeCursorImage(
    width: UInt32,
    height: UInt32,
    hotspotX: UInt32,
    hotspotY: UInt32
) throws -> CursorImage {
    try CursorImage(
        width: width,
        height: height,
        hotspotX: hotspotX,
        hotspotY: hotspotY,
        delay: 0,
        buffer: RawBorrowedBuffer(
            pointer: try unsafe #require(OpaquePointer(bitPattern: 0xB00)))
    )
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
                uncheckedAdvertisedCapabilities: activeCapabilities,
                activeCapabilities: activeCapabilities,
                name: nil
            )
        )
    )
}
