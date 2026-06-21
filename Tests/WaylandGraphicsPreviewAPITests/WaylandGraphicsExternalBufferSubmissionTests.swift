// swiftlint:disable file_length

import Glibc
import Synchronization
import Testing
import WaylandClient
import WaylandGraphicsPreview

@testable import WaylandRaw

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
    func planeIndexAboveUInt32RangeIsRejected() throws {
        let closedDescriptors = Mutex<[Int32]>([])
        let descriptor = try OwnedFileDescriptor(adopting: 778) { descriptor in
            closedDescriptors.withLock { $0.append(descriptor) }
            return 0
        }

        do {
            _ = try WaylandGraphicsExternalBufferPlane(
                fd: descriptor,
                offset: 0,
                stride: 16,
                planeIndex: Int(UInt32.max) + 1
            )
            Issue.record("expected invalid external buffer plane")
        } catch WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor) {
            #expect(closedDescriptors.withLock { $0 } == [778])
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
                presentationMode: .externalGPU,
                synchronizationPolicy: .requireExplicit
            )
        )
        let lease = try await storage.nextFrame()

        do {
            _ = try await registerTestExternalBuffer(
                storage: storage,
                lease: lease,
                descriptor: try testExternalDescriptor()
            )
            Issue.record("expected explicit synchronization failure")
        } catch WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable) {
            #expect(await window.importRequests == 0)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func requireExplicitExternalBufferReachesImportWhenExplicitSyncAvailable() async throws {
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed,
            surfaceFeedbackSynchronization: .explicitAvailable(version: 1)
        )
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .projected(capabilities: gpuCapableSurfaceCapabilities()),
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                synchronizationPolicy: .requireExplicit
            )
        )
        let lease = try await storage.nextFrame()

        #expect(lease.contract.synchronization == .explicitAvailable)
        do {
            _ = try await registerTestExternalBuffer(
                storage: storage,
                lease: lease,
                descriptor: try testExternalDescriptor()
            )
            Issue.record("expected no render node failure")
        } catch WaylandGraphicsError.unavailable(.noRenderNode) {
            _ = ()
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        #expect(await window.importRequests == 1)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting().isEmpty)
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)

        try await storage.closeForTesting()
    }

    @Test
    func externalGPUFallbackPolicyAllowsSoftwareLeaseWhenSurfaceFeedbackFails() async throws {
        let window = try ExternalBufferFakeManagedWindow(
            surfaceFeedbackSynchronization: nil
        )
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .projected(capabilities: gpuCapableSurfaceCapabilities()),
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                fallbackPolicy: .preferGPUFallbackToSoftware
            )
        )

        let lease = try await storage.nextFrame()

        #expect(lease.contract.externalBufferConfigurations.isEmpty)
        #expect(lease.runtimePath.backing == .fallback(.surfaceFeedbackUnavailable))
        #expect(lease.runtimePath.surfaceFeedback == .fallback(.surfaceFeedbackUnavailable))

        let result = try await lease.submitSoftware { _ in
            _ = ()
        }
        #expect(result.runtimePath.backing == .fallback(.surfaceFeedbackUnavailable))

        try await storage.closeForTesting()
    }

    @Test
    func registerExternalBufferRejectsForeignFrameContract() async throws {
        let firstWindow = try ExternalBufferFakeManagedWindow(
            windowID: WindowID(rawValue: 910)
        )
        let secondWindow = try ExternalBufferFakeManagedWindow(
            windowID: WindowID(rawValue: 911),
            importBehavior: .succeed
        )
        let firstStorage = externalBufferStorage(window: firstWindow)
        let secondStorage = externalBufferStorage(window: secondWindow)
        let foreignLease = try await firstStorage.nextFrame()
        let configurationID = try #require(
            foreignLease.contract.recommendedExternalConfigurationID)

        do {
            _ = try await secondStorage.registerExternalBuffer(
                try testExternalDescriptor(),
                contract: foreignLease.contract,
                configurationID: configurationID
            )
            Issue.record("expected foreign frame contract rejection")
        } catch WaylandGraphicsError.staleFrameContract {
            #expect(await secondWindow.importRequests == 0)
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        await foreignLease.cancel()
        try await firstStorage.closeForTesting()
        try await secondStorage.closeForTesting()
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

        #expect(lease.contract.externalBufferConfigurations.isEmpty)
        #expect(lease.contract.recommendedExternalConfigurationID == nil)
        #expect(await window.importRequests == 0)
    }

    @Test
    func externalContractUsesSurfaceFeedbackCandidates() async throws {
        let window = try ExternalBufferFakeManagedWindow()
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()

        #expect(
            lease.contract.externalBufferConfigurations.map(\.format) == [
                .xrgb8888, .argb8888,
            ])
        #expect(
            lease.contract.externalBufferConfigurations.map(\.modifier) == [
                .linear, .linear,
            ])
        #expect(
            lease.contract.externalBufferConfigurations.map(\.scanoutPreferred) == [
                true, true,
            ])
        #expect(
            lease.contract.externalBufferConfigurations.map(\.renderNode.path) == [
                nil, nil,
            ])
        #expect(
            lease.contract.recommendedExternalConfigurationID
                == lease.contract.externalBufferConfigurations.first?.id
        )
        #expect(await window.importRequests == 0)
    }

    @Test
    func externalContractKeepsDistinctTrancheCandidates() async throws {
        let window = try ExternalBufferFakeManagedWindow(
            includeDistinctDuplicateSurfaceFeedback: true
        )
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()

        #expect(
            lease.contract.externalBufferConfigurations.map(\.format) == [
                .xrgb8888, .argb8888, .xrgb8888,
            ])
        #expect(
            lease.contract.externalBufferConfigurations.map(\.modifier) == [
                .linear, .linear, .linear,
            ])
        #expect(
            lease.contract.externalBufferConfigurations.map(\.scanoutPreferred) == [
                true, true, false,
            ])
        #expect(await window.importRequests == 0)
    }

    @Test
    func offsetEdgeFailsAtImportAndCloseDescriptor() async throws {
        let window = try ExternalBufferFakeManagedWindow()
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let closedDescriptors = Mutex<[Int32]>([])
        let descriptor = try testExternalDescriptor(
            modifier: WaylandGraphicsDRMFormatModifier.linear.rawValue,
            offset: UInt32.max,
            fd: OwnedFileDescriptor(adopting: 777) { descriptor in
                closedDescriptors.withLock { $0.append(descriptor) }
                return 0
            }
        )

        do {
            _ = try await registerTestExternalBuffer(
                storage: storage,
                lease: lease,
                descriptor: descriptor
            )
            Issue.record("expected import failure for unsupported descriptor facts")
        } catch WaylandGraphicsError.unavailable(.externalBufferImportFailed) {
            #expect(await window.importRequests == 1)
            #expect(closedDescriptors.withLock { $0 } == [777])
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

@Suite
struct WaylandGraphicsExternalBufferLifecycleTests {
    @Test
    func firstExternalBufferShowPreparesInitialConfigureBeforeImport() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()

        _ = try await registerAndSubmitTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor()
        )

        #expect(await window.preparePresentationRequests == 1)
        #expect(await window.importRequests == 1)

        try await storage.closeForTesting()
    }

    @Test
    func successfulExternalBufferWaitsForReleaseBeforeReusingSlot() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)

        let firstLease = try await storage.nextFrame()
        let first = try await registerAndSubmitTestExternalBuffer(
            storage: storage,
            lease: firstLease,
            descriptor: try testExternalDescriptor()
        )
        let firstRelease = Task {
            await first.receipt.waitForRelease()
        }

        #expect(first.receipt.frameResult.runtimePath.backing == .active)
        #expect(first.receipt.frameResult.runtimePath.dmabufImport == .active)
        #expect(await window.importRequests == 1)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting() == [0])
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)

        let secondLease = try await storage.nextFrame()
        _ = try await registerAndSubmitTestExternalBuffer(
            storage: storage,
            lease: secondLease,
            descriptor: try testExternalDescriptor()
        )

        #expect(await window.importRequests == 2)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting() == [0, 1])
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)

        await window.emitImportedBufferRelease(at: 0)

        #expect(await firstRelease.value == .released)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting() == [1])
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting() == [0])

        let thirdLease = try await storage.nextFrame()
        let thirdRenderLease = try await thirdLease.reserveExternalBuffer(first.buffer)
        _ = try await thirdRenderLease.submit()

        #expect(await window.importRequests == 2)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting() == [0, 1])
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)

        try await storage.closeForTesting()
    }

    @Test
    func commitFailureLeavesImportedExternalBufferTrackedForRecovery() async throws {
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed,
            presentationFailuresBeforeSuccess: 1
        )
        let storage = externalBufferStorage(window: window)

        let failingLease = try await storage.nextFrame()
        let buffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: failingLease,
            descriptor: try testExternalDescriptor()
        )
        do {
            let renderLease = try await failingLease.reserveExternalBuffer(buffer)
            _ = try await renderLease.submit()
            Issue.record("expected external buffer commit failure")
        } catch WaylandGraphicsError.unavailable(.commitFailed) {
            #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting().isEmpty)
            #expect(await storage.externalBufferAvailableSlotRawValuesForTesting() == [0])
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        let recoveryLease = try await storage.nextFrame()
        let recoveryRenderLease = try await recoveryLease.reserveExternalBuffer(buffer)
        let result = try await recoveryRenderLease.submit()

        #expect(result.frameResult.runtimePath.backing == .active)
        #expect(await window.importRequests == 1)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting() == [0])

        try await storage.closeForTesting()
    }

    @Test
    func closeWhileExternalBufferSubmittedRetiresStateAndIgnoresLateRelease() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()

        let submitted = try await registerAndSubmitTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor()
        )
        let release = Task {
            await submitted.receipt.waitForRelease()
        }

        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting() == [0])

        try await storage.closeForTesting()
        await window.emitImportedBufferRelease(at: 0)

        #expect(await release.value == .backingClosed)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting().isEmpty)
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)
    }

    @Test
    func reserveAfterLeaseCancelDoesNotSubmitExternalBuffer() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let buffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor()
        )

        await lease.cancel()

        do {
            _ = try await lease.reserveExternalBuffer(buffer)
            Issue.record("expected consumed lease failure")
        } catch WaylandGraphicsError.frameLeaseConsumed {
            #expect(await window.importRequests == 1)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func submitAfterBackingCloseDoesNotImportExternalBuffer() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()

        try await storage.closeForTesting()

        do {
            _ = try await registerTestExternalBuffer(
                storage: storage,
                lease: lease,
                descriptor: try testExternalDescriptor()
            )
            Issue.record("expected backing closed failure")
        } catch WaylandGraphicsError.backingClosed {
            #expect(await window.importRequests == 0)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func externalBufferSubmitsMetadataScheduleAndFeedbackRequest() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(
            window: window,
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                fallbackPolicy: .requireGPU,
                metadataPolicy: .preferAvailable
            )
        )
        let lease = try await storage.nextFrame()
        let metadata = WaylandGraphicsFrameMetadata(
            contentType: .game,
            presentationHint: .async,
            alpha: .opaque,
            colorRepresentation: WaylandGraphicsColorRepresentation(alphaMode: .straight)
        )
        let schedule = WaylandGraphicsFrameSchedule(
            pacing: .fifo,
            presentationFeedback: .requestWhenAvailable
        )

        let submitted = try await registerAndSubmitTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor(),
            metadata: metadata,
            schedule: schedule
        )
        let result = submitted.receipt

        #expect(result.frameResult.metadata == metadata)
        #expect(result.frameResult.schedule == schedule)
        #expect(result.frameResult.presentationFeedbackRequested)
        #expect(await window.submitConstraintsSnapshot().map(\.pacing) == [.fifo(.setBarrier)])
        #expect(await window.presentationFeedbackRequestSnapshot() == [true])
        #expect(await window.metadataSnapshot().compactMap(\.contentType) == [.game])
        #expect(await window.metadataSnapshot().compactMap(\.presentationHint) == [.async])
        #expect(
            await window.metadataSnapshot().compactMap(\.alpha)
                == [SurfaceAlphaMetadata(multiplier: .opaque)]
        )
        #expect(
            await window.metadataSnapshot().compactMap(\.colorRepresentation?.alphaMode)
                == [.straight]
        )

        try await storage.closeForTesting()
    }

    @Test
    func registeredExternalBufferImportsOnceAndSubmitsAfterReservation() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let configurationID = try #require(
            lease.contract.recommendedExternalConfigurationID)
        let descriptor = try testExternalDescriptor(
            modifier: WaylandGraphicsDRMFormatModifier.linear.rawValue,
            offset: 0,
            fd: testOwnedFileDescriptor()
        )

        let buffer = try await storage.registerExternalBuffer(
            descriptor,
            contract: lease.contract,
            configurationID: configurationID
        )
        let renderLease = try await lease.reserveExternalBuffer(buffer)
        let receipt = try await renderLease.submit()

        #expect(await window.importRequests == 1)
        #expect(receipt.frameResult.runtimePath.backing == .active)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting() == [0])

        try await storage.closeForTesting()
    }

    @Test
    func registeredExternalBufferCannotReserveAgainUntilRelease() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let firstLease = try await storage.nextFrame()
        let configurationID = try #require(
            firstLease.contract.recommendedExternalConfigurationID)
        let descriptor = try testExternalDescriptor(
            modifier: WaylandGraphicsDRMFormatModifier.linear.rawValue,
            offset: 0,
            fd: testOwnedFileDescriptor()
        )
        let buffer = try await storage.registerExternalBuffer(
            descriptor,
            contract: firstLease.contract,
            configurationID: configurationID
        )

        let firstRenderLease = try await firstLease.reserveExternalBuffer(buffer)
        let firstReceipt = try await firstRenderLease.submit()
        let blockedLease = try await storage.nextFrame()
        do {
            _ = try await blockedLease.reserveExternalBuffer(buffer)
            Issue.record("expected registered external buffer to remain busy")
        } catch WaylandGraphicsError.externalBufferUnavailable {
            await blockedLease.cancel()
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        await window.emitImportedBufferRelease(at: 0)
        #expect(await firstReceipt.waitForRelease() == .released)

        let secondLease = try await storage.nextFrame()
        let secondRenderLease = try await secondLease.reserveExternalBuffer(buffer)
        _ = try await secondRenderLease.submit()

        #expect(await window.importRequests == 1)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting() == [0])

        try await storage.closeForTesting()
    }

    @Test
    func registeredExternalBufferCanUnregisterWhenAvailable() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let configurationID = try #require(
            lease.contract.recommendedExternalConfigurationID)
        let buffer = try await storage.registerExternalBuffer(
            try testExternalDescriptor(
                modifier: WaylandGraphicsDRMFormatModifier.linear.rawValue,
                offset: 0,
                fd: testOwnedFileDescriptor()
            ),
            contract: lease.contract,
            configurationID: configurationID
        )

        try await storage.unregisterExternalBuffer(buffer)

        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)

        do {
            _ = try await lease.reserveExternalBuffer(buffer)
            Issue.record("expected unregistered external buffer to be unavailable")
        } catch WaylandGraphicsError.externalBufferUnavailable {
            await lease.cancel()
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        try await storage.closeForTesting()
    }

    @Test
    func registeredExternalBufferUnregisterRequiresRelease() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let configurationID = try #require(
            lease.contract.recommendedExternalConfigurationID)
        let buffer = try await storage.registerExternalBuffer(
            try testExternalDescriptor(
                modifier: WaylandGraphicsDRMFormatModifier.linear.rawValue,
                offset: 0,
                fd: testOwnedFileDescriptor()
            ),
            contract: lease.contract,
            configurationID: configurationID
        )
        let renderLease = try await lease.reserveExternalBuffer(buffer)
        let receipt = try await renderLease.submit()

        do {
            try await storage.unregisterExternalBuffer(buffer)
            Issue.record("expected busy external buffer unregister to fail")
        } catch WaylandGraphicsError.externalBufferUnavailable {
            _ = ()
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        await window.emitImportedBufferRelease(at: 0)
        #expect(await receipt.waitForRelease() == .released)

        try await storage.unregisterExternalBuffer(buffer)
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)

        try await storage.closeForTesting()
    }

    @Test
    func availableRegisteredBufferRetiresWhenContractGenerationChanges() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let firstLease = try await storage.nextFrame()
        let buffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: firstLease,
            descriptor: try testExternalDescriptor(
                modifier: WaylandGraphicsDRMFormatModifier.linear.rawValue,
                offset: 0,
                fd: testOwnedFileDescriptor()
            )
        )
        await firstLease.cancel()

        await window.setGeometry(try testGraphicsSurfaceGeometry(width: 128, height: 96))
        let secondLease = try await storage.nextFrame()

        #expect(secondLease.contract.generation != firstLease.contract.generation)
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)

        do {
            _ = try await secondLease.reserveExternalBuffer(buffer)
            Issue.record("expected old-generation external buffer to be retired")
        } catch WaylandGraphicsError.externalBufferUnavailable {
            await secondLease.cancel()
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        try await storage.closeForTesting()
    }

    @Test
    func submittedStaleRegisteredBufferRetiresAfterRelease() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let firstLease = try await storage.nextFrame()
        let buffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: firstLease,
            descriptor: try testExternalDescriptor(
                modifier: WaylandGraphicsDRMFormatModifier.linear.rawValue,
                offset: 0,
                fd: testOwnedFileDescriptor()
            )
        )
        let renderLease = try await firstLease.reserveExternalBuffer(buffer)
        let receipt = try await renderLease.submit()

        await window.setGeometry(try testGraphicsSurfaceGeometry(width: 128, height: 96))
        let secondLease = try await storage.nextFrame()

        #expect(secondLease.contract.generation != firstLease.contract.generation)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting() == [0])

        await window.emitImportedBufferRelease(at: 0)
        #expect(await receipt.waitForRelease() == .released)
        for _ in 0..<10 {
            if await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty {
                break
            }
            await Task.yield()
        }

        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting().isEmpty)
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)

        do {
            _ = try await secondLease.reserveExternalBuffer(buffer)
            Issue.record("expected released old-generation external buffer to be retired")
        } catch WaylandGraphicsError.externalBufferUnavailable {
            await secondLease.cancel()
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        try await storage.closeForTesting()
    }
}

private actor ExternalBufferFakeManagedWindow: WaylandGraphicsManagedWindow {
    enum ImportBehavior: Sendable {
        case fail
        case succeed
    }

    nonisolated let id: WindowID
    private var geometryValue: SurfaceGeometry
    private let importBehavior: ImportBehavior
    private var presentationFailuresBeforeSuccess: Int
    private var nextGeneration: UInt64 = 1
    private(set) var importRequests = 0
    private var isWindowClosed = false
    private var importedBuffers: [RawLinuxDmabufBuffer] = []
    private var submitConstraints: [SurfaceSubmitConstraints] = []
    private var submittedMetadata: [SurfaceCommitMetadata] = []
    private var presentationFeedbackRequests: [Bool] = []
    private(set) var preparePresentationRequests = 0
    private let surfaceFeedbackSynchronization: SurfaceSynchronizationCapability?
    private let includeDistinctDuplicateSurfaceFeedback: Bool

    init(
        windowID backingWindowID: WindowID = WindowID(rawValue: 910),
        importBehavior requestedImportBehavior: ImportBehavior = .fail,
        presentationFailuresBeforeSuccess requestedPresentationFailures: Int = 0,
        surfaceFeedbackSynchronization requestedSurfaceFeedbackSynchronization:
            SurfaceSynchronizationCapability? = .implicitOnly,
        includeDistinctDuplicateSurfaceFeedback shouldIncludeDistinctDuplicateSurfaceFeedback:
            Bool = false
    ) throws {
        id = backingWindowID
        geometryValue = try testGraphicsSurfaceGeometry()
        importBehavior = requestedImportBehavior
        presentationFailuresBeforeSuccess = requestedPresentationFailures
        surfaceFeedbackSynchronization = requestedSurfaceFeedbackSynchronization
        includeDistinctDuplicateSurfaceFeedback = shouldIncludeDistinctDuplicateSurfaceFeedback
    }

    var geometry: SurfaceGeometry {
        get async throws { geometryValue }
    }

    func setGeometry(_ geometry: SurfaceGeometry) {
        geometryValue = geometry
    }

    var isClosed: Bool {
        get async throws { isWindowClosed }
    }

    func prepareGraphicsPreviewPresentation(
        timeoutMilliseconds _: Int32
    ) async throws -> SurfaceGeometry {
        preparePresentationRequests += 1
        return geometryValue
    }

    func requestGraphicsPreviewSurfaceFeedback(
        timeoutMilliseconds _: Int32
    ) async throws -> SurfaceCapabilitySnapshot {
        guard let surfaceFeedbackSynchronization else {
            throw GraphicsPreviewSurfaceFeedbackError.surfaceFeedbackUnavailable
        }

        return try testSurfaceCapabilitySnapshotWithDmabufFeedback(
            synchronization: surfaceFeedbackSynchronization,
            includeDistinctDuplicateTranche: includeDistinctDuplicateSurfaceFeedback
        )
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
        switch importBehavior {
        case .fail:
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        case .succeed:
            let buffer = try testRawLinuxDmabufBuffer(
                pointer: UInt(0xE0_000 + importRequests)
            )
            importedBuffers.append(buffer)
            return buffer
        }
    }

    func presentGraphicsPreviewBuffer(
        _ buffer: RawSurfaceBuffer,
        submitConstraints submittedConstraints: SurfaceSubmitConstraints,
        metadata submittedFrameMetadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool
    ) async throws -> PreviewBufferPresentationResult {
        _ = buffer
        guard !isWindowClosed else {
            throw WaylandGraphicsError.windowClosed
        }

        submitConstraints.append(submittedConstraints)
        submittedMetadata.append(submittedFrameMetadata)
        presentationFeedbackRequests.append(requestPresentationFeedback)

        guard presentationFailuresBeforeSuccess == 0 else {
            presentationFailuresBeforeSuccess -= 1
            throw WaylandGraphicsError.unavailable(.commitFailed)
        }

        defer { nextGeneration += 1 }
        return try testPreviewBufferPresentationResult(generation: nextGeneration)
    }

    func submitConstraintsSnapshot() -> [SurfaceSubmitConstraints] {
        submitConstraints
    }

    func metadataSnapshot() -> [SurfaceCommitMetadata] {
        submittedMetadata
    }

    func presentationFeedbackRequestSnapshot() -> [Bool] {
        presentationFeedbackRequests
    }

    func emitImportedBufferRelease(at index: Int) {
        guard importedBuffers.indices.contains(index) else { return }

        importedBuffers[index].emitReleaseForTesting()
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
        isWindowClosed = true
    }
}

private func externalBufferStorage(
    window: ExternalBufferFakeManagedWindow,
    configuration: WaylandGraphicsConfiguration = WaylandGraphicsConfiguration(
        presentationMode: .externalGPU,
        fallbackPolicy: .requireGPU
    )
) -> WaylandGraphicsWindowBackingStorage {
    WaylandGraphicsWindowBackingStorage(
        window: window,
        runtimePath: .projected(capabilities: gpuCapableSurfaceCapabilities()),
        configuration: configuration
    )
}

private func testGraphicsSurfaceGeometry(width: Int, height: Int) throws -> SurfaceGeometry {
    try SurfaceGeometry(
        logicalSize: PositiveLogicalSize(width: Int32(width), height: Int32(height)),
        scale: .one
    )
}

private func registerAndSubmitTestExternalBuffer(
    storage: WaylandGraphicsWindowBackingStorage,
    lease: WaylandGraphicsFrameLease,
    descriptor: consuming WaylandGraphicsExternalBufferDescriptor,
    metadata frameMetadata: WaylandGraphicsFrameMetadata = .default,
    schedule frameSchedule: WaylandGraphicsFrameSchedule? = nil
) async throws -> (
    buffer: WaylandGraphicsExternalBuffer,
    receipt: WaylandGraphicsExternalBufferSubmissionReceipt
) {
    let buffer = try await registerTestExternalBuffer(
        storage: storage,
        lease: lease,
        descriptor: descriptor
    )
    let renderLease = try await lease.reserveExternalBuffer(buffer)
    let receipt = try await renderLease.submit(
        metadata: frameMetadata,
        schedule: frameSchedule
    )
    return (buffer, receipt)
}

private func registerTestExternalBuffer(
    storage: WaylandGraphicsWindowBackingStorage,
    lease: WaylandGraphicsFrameLease,
    descriptor: consuming WaylandGraphicsExternalBufferDescriptor
) async throws -> WaylandGraphicsExternalBuffer {
    let configurationID = try #require(
        lease.contract.recommendedExternalConfigurationID)
    return try await storage.registerExternalBuffer(
        descriptor,
        contract: lease.contract,
        configurationID: configurationID
    )
}

private func testRawLinuxDmabufBuffer(pointer rawPointer: UInt) throws -> RawLinuxDmabufBuffer {
    let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))
    return unsafe RawLinuxDmabufBuffer(testingPointer: pointer)
}

private func testPreviewBufferPresentationResult(
    generation: UInt64
) throws -> PreviewBufferPresentationResult {
    try PreviewBufferPresentationResult(
        generation: generation,
        commitPlan: try SurfaceCommitPlan(
            geometry: try testGraphicsSurfaceGeometry(),
            bufferScale: 1,
            viewportMode: .omitDestination,
            damageMode: .buffer
        ),
        capabilities: SurfaceCapabilitySnapshot(
            role: .toplevelWindow,
            outputIDs: [],
            fractionalScale: .integerOnly,
            presentationFeedback: .available,
            dmabuf: .advertised(
                version: 4,
                canRequestSurfaceFeedback: .available
            ),
            synchronization: .implicitOnly,
            pacing: .fifoAndCommitTiming(fifo: 1, commitTiming: 1),
            contentType: .available,
            alphaModifier: .available,
            tearingControl: .available,
            colorRepresentation: .available(
                version: 1,
                support: SurfaceColorRepresentationSupport(alphaModes: [.straight])
            ),
            color: .available(version: 1)
        )
    )
}

private func testSurfaceCapabilitySnapshotWithDmabufFeedback(
    synchronization: SurfaceSynchronizationCapability = .implicitOnly,
    includeDistinctDuplicateTranche: Bool = false
)
    throws -> SurfaceCapabilitySnapshot
{
    let surfaceID = RawObjectID(42)
    let feedback = try SurfaceDmabufFeedback(
        snapshot: testSurfaceDmabufFeedbackSnapshot(
            surfaceID: surfaceID,
            includeDistinctDuplicateTranche: includeDistinctDuplicateTranche
        ),
        surfaceID: surfaceID
    )
    return SurfaceCapabilitySnapshot(
        role: .toplevelWindow,
        outputIDs: [],
        fractionalScale: .integerOnly,
        presentationFeedback: .available,
        dmabuf: .surfaceFeedback(
            version: 4,
            feedback: feedback
        ),
        synchronization: synchronization,
        pacing: .fifoAndCommitTiming(fifo: 1, commitTiming: 1),
        contentType: .available,
        alphaModifier: .available,
        tearingControl: .available,
        colorRepresentation: .available(
            version: 1,
            support: SurfaceColorRepresentationSupport(alphaModes: [.straight])
        ),
        color: .available(version: 1)
    )
}

private func testSurfaceDmabufFeedbackSnapshot(
    surfaceID: RawObjectID,
    includeDistinctDuplicateTranche: Bool = false
) throws -> RawLinuxDmabufFeedbackSnapshot {
    let formats = [
        RawLinuxDmabufFormatModifier(
            format: WaylandGraphicsDRMFormat.xrgb8888.rawValue,
            modifier: WaylandGraphicsDRMFormatModifier.linear.rawValue
        ),
        RawLinuxDmabufFormatModifier(
            format: WaylandGraphicsDRMFormat.argb8888.rawValue,
            modifier: WaylandGraphicsDRMFormatModifier.linear.rawValue
        ),
    ]
    var state = RawLinuxDmabufFeedbackState()
    state.replaceFormatTable(formats)
    try state.setMainDevice(bytes: [1, 2, 3, 4, 5, 6, 7, 8], scope: .surface(surfaceID: surfaceID))
    try state.setCurrentTrancheTargetDevice(
        bytes: [1, 2, 3, 4, 5, 6, 7, 8],
        scope: .surface(surfaceID: surfaceID)
    )
    try state.setCurrentTrancheFlags(
        RawLinuxDmabufTrancheFlags.scanout.rawValue,
        scope: .surface(surfaceID: surfaceID)
    )
    try state.appendCurrentTrancheFormats(indices: [0, 1], scope: .surface(surfaceID: surfaceID))
    try state.finishCurrentTranche(scope: .surface(surfaceID: surfaceID))
    if includeDistinctDuplicateTranche {
        try state.setCurrentTrancheTargetDevice(
            bytes: [8, 7, 6, 5, 4, 3, 2, 1],
            scope: .surface(surfaceID: surfaceID)
        )
        try state.setCurrentTrancheFlags(0, scope: .surface(surfaceID: surfaceID))
        try state.appendCurrentTrancheFormats(indices: [0], scope: .surface(surfaceID: surfaceID))
        try state.finishCurrentTranche(scope: .surface(surfaceID: surfaceID))
    }
    return try state.finish(scope: .surface(surfaceID: surfaceID))
}

private func testExternalDescriptor() throws -> WaylandGraphicsExternalBufferDescriptor {
    try testExternalDescriptor(
        modifier: 0,
        offset: 0,
        fd: testOwnedFileDescriptor()
    )
}

private func testExternalDescriptor(
    modifier: UInt64,
    offset: UInt32,
    fd: consuming OwnedFileDescriptor
) throws -> WaylandGraphicsExternalBufferDescriptor {
    try WaylandGraphicsExternalBufferDescriptor(
        size: testGraphicsSurfaceGeometry().bufferSize,
        format: WaylandGraphicsDRMFormat(rawValue: 875_713_112),
        modifier: WaylandGraphicsDRMFormatModifier(rawValue: modifier),
        planes: .one(try testExternalPlane(index: 0, offset: offset, fd: fd))
    )
}

private func testExternalPlane(index: Int) throws -> WaylandGraphicsExternalBufferPlane {
    try testExternalPlane(index: index, offset: 0, fd: testOwnedFileDescriptor())
}

private func testExternalPlane(
    index: Int,
    offset: UInt32,
    fd: consuming OwnedFileDescriptor
) throws -> WaylandGraphicsExternalBufferPlane {
    try WaylandGraphicsExternalBufferPlane(
        fd: fd,
        offset: offset,
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
