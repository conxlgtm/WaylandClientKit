import Glibc
import Testing
import WaylandClient
import WaylandGraphicsPreview
import WaylandRaw

@Suite
struct WaylandGraphicsExternalBufferDescriptorTests {
    @Test
    func invalidDRMFormatIsRejected() {
        #expect(throws: WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)) {
            _ = try WaylandGraphicsDRMFormat(rawValue: 0)
        }
    }

    @Test
    func zeroStridePlaneIsRejected() throws {
        let descriptor = try testOwnedFileDescriptor()

        do {
            _ = try WaylandGraphicsExternalBufferPlane(
                fd: descriptor,
                offset: 0,
                stride: 0,
                planeIndex: 0
            )
            Issue.record("expected invalid external buffer plane")
        } catch WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor) {
            _ = ()
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func duplicatePlaneIndexIsRejected() throws {
        let size = try PositivePixelSize(width: 4, height: 4)
        let format = try WaylandGraphicsDRMFormat(rawValue: 875_713_112)
        let modifier = WaylandGraphicsDRMFormatModifier(rawValue: 0)
        let first = try testExternalPlane(index: 0)
        let second = try testExternalPlane(index: 0)

        do {
            _ = try WaylandGraphicsExternalBufferDescriptor(
                size: size,
                format: format,
                modifier: modifier,
                planes: .two(first, second)
            )
            Issue.record("expected duplicate plane index rejection")
        } catch WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor) {
            _ = ()
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func nonConsecutivePlaneIndicesAreRejected() throws {
        let size = try PositivePixelSize(width: 4, height: 4)
        let format = try WaylandGraphicsDRMFormat(rawValue: 875_713_112)
        let modifier = WaylandGraphicsDRMFormatModifier(rawValue: 0)
        let first = try testExternalPlane(index: 0)
        let second = try testExternalPlane(index: 2)

        do {
            _ = try WaylandGraphicsExternalBufferDescriptor(
                size: size,
                format: format,
                modifier: modifier,
                planes: .two(first, second)
            )
            Issue.record("expected non-consecutive plane index rejection")
        } catch WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor) {
            _ = ()
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func validDescriptorCreatesImportPlan() throws {
        var descriptor = try testExternalDescriptor()
        let plan = try descriptor.makeImportPlan()

        withExtendedLifetime(plan) {
            _ = ()
        }
    }
}

@Suite
struct WaylandGraphicsExternalBufferPreflightTests {
    @Test
    func requireExplicitExternalBufferFailsBeforeImport() async throws {
        let window = try ExternalBufferFakeManagedWindow()
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .projected(capabilities: gpuCapableSurfaceCapabilities()),
            configuration: WaylandGraphicsConfiguration(
                synchronizationPolicy: .requireExplicit
            )
        )
        let lease = try await storage.nextFrame()

        do {
            _ = try await lease.submitExternalBuffer(try testExternalDescriptor())
            Issue.record("expected explicit synchronization failure")
        } catch WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable) {
            #expect(await window.importRequests == 0)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func forceSoftwareExternalBufferFailsBeforeImport() async throws {
        let window = try ExternalBufferFakeManagedWindow()
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .projected(capabilities: gpuCapableSurfaceCapabilities()),
            configuration: WaylandGraphicsConfiguration(
                fallbackPolicy: .forceSoftware
            )
        )
        let lease = try await storage.nextFrame()

        do {
            _ = try await lease.submitExternalBuffer(try testExternalDescriptor())
            Issue.record("expected managed GPU unavailable failure")
        } catch WaylandGraphicsError.unavailable(.managedGPUSubmissionUnavailable) {
            #expect(await window.importRequests == 0)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func scheduleIsRecordedInFrameResult() async throws {
        let window = try ExternalBufferFakeManagedWindow()
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .softwareFallback(
                capabilities: gpuCapableSurfaceCapabilities(),
                reason: .forcedSoftware
            ),
            configuration: WaylandGraphicsConfiguration(backingPreference: .software)
        )
        let lease = try await storage.nextFrame()
        let schedule = WaylandGraphicsFrameSchedule(
            pacing: .fifo,
            presentationFeedback: .requestWhenAvailable
        )

        let result = try await lease.submitSoftware(schedule: schedule) { _ in
            _ = ()
        }

        #expect(result.schedule == schedule)
        #expect(result.runtimePath.pacing.fifo == .active)
        #expect(result.presentationFeedbackRequested)
    }
}

private actor ExternalBufferFakeManagedWindow: WaylandGraphicsManagedWindow {
    nonisolated let id = WindowID(rawValue: 910)
    private let geometryValue: SurfaceGeometry
    private(set) var importRequests = 0

    init() throws {
        geometryValue = try testGraphicsSurfaceGeometry()
    }

    var geometry: SurfaceGeometry {
        get async throws { geometryValue }
    }

    var isClosed: Bool {
        get async throws { false }
    }

    func importGraphicsPreviewExternalBuffer(
        _ descriptor: consuming WaylandGraphicsExternalBufferDescriptor
    ) async throws -> RawLinuxDmabufBuffer {
        var descriptor = descriptor
        importRequests += 1
        do {
            try descriptor.closeFileDescriptors()
        } catch {
            _ = error
        }
        throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
    }

    // swiftlint:disable:next function_parameter_count
    func show(
        timeoutMilliseconds _: Int32,
        submitConstraints _: SurfaceSubmitConstraints,
        metadata _: SurfaceCommitMetadata,
        requestPresentationFeedback _: Bool,
        damage _: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        _ = draw
    }

    func redraw(
        submitConstraints _: SurfaceSubmitConstraints,
        metadata _: SurfaceCommitMetadata,
        requestPresentationFeedback _: Bool,
        damage _: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        _ = draw
    }

    func close() async {
        _ = ()
    }
}

private func testExternalDescriptor() throws -> WaylandGraphicsExternalBufferDescriptor {
    try WaylandGraphicsExternalBufferDescriptor(
        size: testGraphicsSurfaceGeometry().bufferSize,
        format: WaylandGraphicsDRMFormat(rawValue: 875_713_112),
        modifier: WaylandGraphicsDRMFormatModifier(rawValue: 0),
        planes: .one(try testExternalPlane(index: 0))
    )
}

private func testExternalPlane(index: Int) throws -> WaylandGraphicsExternalBufferPlane {
    try WaylandGraphicsExternalBufferPlane(
        fd: testOwnedFileDescriptor(),
        offset: 0,
        stride: 16,
        planeIndex: index
    )
}

private func testOwnedFileDescriptor() throws -> OwnedFileDescriptor {
    var descriptors = [Int32](repeating: -1, count: 2)
    let result = unsafe descriptors.withUnsafeMutableBufferPointer { buffer in
        unsafe Glibc.pipe(buffer.baseAddress)
    }
    guard result == 0 else {
        throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
    }

    Glibc.close(descriptors[1])
    return try OwnedFileDescriptor(adopting: descriptors[0])
}
