import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsExplicitSubmissionPolicyTests {
    @Test
    func requireExplicitRejectsDirectSoftwareSubmission() async throws {
        let window = try ExplicitPolicyFakeManagedWindow()
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .projected(capabilities: gpuCapableSurfaceCapabilities()),
            configuration: WaylandGraphicsConfiguration(
                synchronizationPolicy: .requireExplicit
            )
        )
        let lease = try await storage.nextFrame()

        do {
            _ = try await lease.submitSoftware { _ in
                _ = ()
            }
            Issue.record("expected direct software submission rejection")
        } catch WaylandGraphicsError.unavailable(.managedGPUSubmissionUnavailable) {
            #expect(await window.operations().isEmpty)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func requireExplicitRejectsClearFrameSoftwareFallback() async throws {
        let window = try ExplicitPolicyFakeManagedWindow()
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .projected(capabilities: gpuCapableSurfaceCapabilities()),
            configuration: WaylandGraphicsConfiguration(
                synchronizationPolicy: .requireExplicit
            )
        )
        let lease = try await storage.nextFrame()

        do {
            _ = try await lease.submit(.clearColor(.black))
            Issue.record("expected clear-frame software fallback rejection")
        } catch WaylandGraphicsError.unavailable(.managedGPUSubmissionUnavailable) {
            #expect(await window.operations().isEmpty)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func requireExplicitRejectsExternalSoftwareFallbackSubmission() async throws {
        let window = try ExplicitPolicyFakeManagedWindow()
        let storage = externalFallbackStorage(window: window)
        let lease = try await storage.nextFrame()

        do {
            _ = try await lease.submitSoftware { _ in
                _ = ()
            }
            Issue.record("expected external software fallback rejection")
        } catch WaylandGraphicsError.unavailable(.managedGPUSubmissionUnavailable) {
            #expect(await window.operations().isEmpty)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func requireExplicitRejectsExternalClearFrameFallback() async throws {
        let window = try ExplicitPolicyFakeManagedWindow()
        let storage = externalFallbackStorage(window: window)
        let lease = try await storage.nextFrame()

        do {
            _ = try await lease.submit(.clearColor(.black))
            Issue.record("expected external clear-frame fallback rejection")
        } catch WaylandGraphicsError.unavailable(.managedGPUSubmissionUnavailable) {
            #expect(await window.operations().isEmpty)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    private func externalFallbackStorage(
        window: ExplicitPolicyFakeManagedWindow
    ) -> WaylandGraphicsWindowBackingStorage {
        let capabilities = gpuCapableSurfaceCapabilities()
        return WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .softwareFallback(
                capabilities: capabilities,
                reason: .surfaceFeedbackUnavailable
            ),
            configuration: WaylandGraphicsConfiguration(
                presentationPolicy: .externalGPU(fallback: .software),
                synchronizationPolicy: .requireExplicit
            )
        )
    }
}

private actor ExplicitPolicyFakeManagedWindow: WaylandGraphicsManagedWindow {
    nonisolated let id = WindowID(rawValue: 712)

    private let geometryValue: SurfaceGeometry
    private var recordedOperations: [WaylandGraphicsSubmissionOperation] = []

    init() throws {
        geometryValue = try testGraphicsSurfaceGeometry()
    }

    var geometry: SurfaceGeometry {
        get async throws {
            geometryValue
        }
    }

    var isClosed: Bool {
        get async throws {
            false
        }
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
        recordedOperations.append(.show)
    }

    func redraw(
        submitConstraints _: SurfaceSubmitConstraints,
        metadata _: SurfaceCommitMetadata,
        requestPresentationFeedback _: Bool,
        damage _: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        _ = draw
        recordedOperations.append(.redraw)
    }

    func close() async {
        _ = ()
    }

    func operations() -> [WaylandGraphicsSubmissionOperation] {
        recordedOperations
    }
}
