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
    func externalGPUFallbackPolicyFailsLeaseWhenSurfaceFeedbackFails() async throws {
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

        await #expect(
            throws: WaylandGraphicsError.unavailable(.surfaceFeedbackUnavailable)
        ) {
            _ = try await storage.nextFrame()
        }

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
struct ExternalImportTransactionTests {
    @Test
    func bufferImportFailureUsesSubmissionPreparationStage() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .clientFailure)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()

        do {
            _ = try await registerTestExternalBuffer(
                storage: storage,
                lease: lease,
                descriptor: try testExternalDescriptor()
            )
            Issue.record("expected imported buffer failure")
        } catch WaylandGraphicsError.submissionFailed(
            .display(
                error: .presentationTimeUnavailable,
                operation: nil,
                stage: .submissionPreparation
            )
        ) {
            // Registration failures are submission preparation diagnostics.
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        await lease.cancel()
        try await storage.closeForTesting()
    }

    @Test(.timeLimit(.minutes(1)))
    func closeDuringBufferImportDestroysUnpublishedResource() async throws {
        let barrier = ExternalImportBarrier()
        let destroyRecorder = ExternalBufferDestroyRecorder()
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed,
            importHooks: ExternalImportTestHooks(
                bufferBarrier: barrier,
                destroyRecorder: destroyRecorder
            )
        )
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let contract = lease.contract
        let configurationID = try #require(contract.recommendedExternalConfigurationID)
        await lease.cancel()

        // swiftlint:disable:next no_unstructured_task
        let registration = Task {
            try await storage.registerExternalBuffer(
                try testExternalDescriptor(),
                contract: contract,
                configurationID: configurationID
            )
        }
        await barrier.waitUntilSuspended()
        try await storage.closeForTesting()
        await barrier.resume()

        do {
            _ = try await registration.value
            Issue.record("expected backing close to invalidate suspended import")
        } catch WaylandGraphicsError.backingClosed {
            // Stable terminal error for the invalidated registration.
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        #expect(destroyRecorder.count == 1)
        #expect(await storage.externalBufferLifecycleSnapshotForTesting().total == 0)
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting().isEmpty)
        #expect(await window.closeRequests == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func generationChangeDuringBufferImportRejectsAndDestroysResource() async throws {
        let barrier = ExternalImportBarrier()
        let destroyRecorder = ExternalBufferDestroyRecorder()
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed,
            importHooks: ExternalImportTestHooks(
                bufferBarrier: barrier,
                destroyRecorder: destroyRecorder
            )
        )
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let staleContract = lease.contract
        let configurationID = try #require(staleContract.recommendedExternalConfigurationID)
        await lease.cancel()

        // swiftlint:disable:next no_unstructured_task
        let registration = Task {
            try await storage.registerExternalBuffer(
                try testExternalDescriptor(),
                contract: staleContract,
                configurationID: configurationID
            )
        }
        await barrier.waitUntilSuspended()
        await window.setGeometry(try testGraphicsSurfaceGeometry(width: 5, height: 4))
        let currentLease = try await storage.nextFrame()
        let currentGeneration = currentLease.contract.generation
        await currentLease.cancel()
        await barrier.resume()

        do {
            _ = try await registration.value
            Issue.record("expected generation change to invalidate suspended import")
        } catch WaylandGraphicsError.staleFrameContract(let rendered, let current) {
            #expect(rendered == staleContract.generation)
            #expect(current == currentGeneration)
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        #expect(destroyRecorder.count == 1)
        #expect(await storage.externalBufferLifecycleSnapshotForTesting().total == 0)
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting().isEmpty)
        try await storage.closeForTesting()
    }

    @Test(.timeLimit(.minutes(1)))
    func closeDuringTimelineImportRemovesUnpublishedResource() async throws {
        let barrier = ExternalImportBarrier()
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed,
            surfaceFeedbackSynchronization: .explicitAvailable(version: 1),
            importHooks: ExternalImportTestHooks(timelineBarrier: barrier)
        )
        let storage = externalBufferStorage(
            window: window,
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                fallbackPolicy: .requireGPU,
                synchronizationPolicy: .preferExplicit
            )
        )

        // swiftlint:disable:next no_unstructured_task
        let timelineImport = Task {
            try await storage.importExternalSyncTimeline(testOwnedFileDescriptor())
        }
        await barrier.waitUntilSuspended()
        let importedIdentities = await window.importedSynchronizationTimelineIdentities()
        #expect(importedIdentities.count == 1)
        try await storage.closeForTesting()
        await barrier.resume()

        do {
            _ = try await timelineImport.value
            Issue.record("expected backing close to invalidate suspended timeline import")
        } catch WaylandGraphicsError.backingClosed {
            // Stable terminal error for the invalidated import.
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        #expect(await storage.importedExternalSyncTimelineIDsForTesting().isEmpty)
        #expect(
            await window.removedSynchronizationTimelineIdentities() == importedIdentities
        )
        #expect(await window.closeRequests == 1)
    }
}

@Suite
struct ExternalBufferSyncTests {
    @Test
    func implicitOnlyAcquireSubmitFails() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(
            window: window,
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                fallbackPolicy: .requireGPU,
                synchronizationPolicy: .implicitOnly
            )
        )
        let lease = try await storage.nextFrame()
        let buffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor()
        )
        let renderLease = try await lease.reserveExternalBuffer(buffer)
        let timeline = WaylandGraphicsExternalSyncTimeline(
            id: WaylandGraphicsExternalSyncTimelineID(rawValue: 100),
            windowID: window.id
        )
        let acquirePoint = try timeline.point(1)
        let acquireSynchronization: WaylandGraphicsExternalAcquireSynchronization =
            .drmSyncobj(acquirePoint)

        await #expect(
            throws: WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable)
        ) {
            _ = try await renderLease.submit(
                acquireSynchronization: acquireSynchronization
            )
        }

        try await storage.closeForTesting()
    }

    @Test
    func preferExplicitAcquireSubmitFailsWhenExplicitFallsBack() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(
            window: window,
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                fallbackPolicy: .requireGPU,
                synchronizationPolicy: .preferExplicit
            )
        )
        let lease = try await storage.nextFrame()
        let buffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor()
        )
        let renderLease = try await lease.reserveExternalBuffer(buffer)
        let timeline = WaylandGraphicsExternalSyncTimeline(
            id: WaylandGraphicsExternalSyncTimelineID(rawValue: 99),
            windowID: window.id
        )
        let acquirePoint = try timeline.point(1)
        let acquireSynchronization: WaylandGraphicsExternalAcquireSynchronization =
            .drmSyncobj(acquirePoint)

        await #expect(
            throws: WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable)
        ) {
            _ = try await renderLease.submit(
                acquireSynchronization: acquireSynchronization
            )
        }

        try await storage.closeForTesting()
    }

    @Test
    func explicitAcquireValidationRejectsForeignUnknownAndZeroPoints() async throws {
        try await expectExplicitAcquireRejected(
            WaylandGraphicsExternalSyncTimeline(
                id: WaylandGraphicsExternalSyncTimelineID(rawValue: 900),
                windowID: WindowID(rawValue: 901)
            ).point(1)
        )
        try await expectExplicitAcquireRejected(
            WaylandGraphicsExternalSyncTimeline(
                id: WaylandGraphicsExternalSyncTimelineID(rawValue: 901),
                windowID: WindowID(rawValue: 910)
            ).point(1)
        )

        let timeline = WaylandGraphicsExternalSyncTimeline(
            id: WaylandGraphicsExternalSyncTimelineID(rawValue: 902),
            windowID: WindowID(rawValue: 910)
        )
        #expect(throws: WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable)) {
            _ = try timeline.point(0)
        }
    }

    @Test
    func backingCloseRemovesImportedAcquireTimelinesAndIsIdempotent() async throws {
        let backend = ExternalReleaseTimelineTestBackend()
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed,
            surfaceFeedbackSynchronization: .explicitAvailable(version: 1)
        )
        let storage = externalBufferStorage(
            window: window,
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                fallbackPolicy: .requireGPU,
                synchronizationPolicy: .preferExplicit
            )
        )
        await storage.useFakeExternalReleaseTimelineForTesting(backend)

        let lease = try await storage.nextFrame()
        _ = try await registerTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor()
        )
        let firstAcquireTimeline = try await storage.importExternalSyncTimeline(
            testOwnedFileDescriptor()
        )
        let secondAcquireTimeline = try await storage.importExternalSyncTimeline(
            testOwnedFileDescriptor()
        )

        #expect(
            await storage.importedExternalSyncTimelineIDsForTesting()
                == Set([firstAcquireTimeline.id, secondAcquireTimeline.id])
        )
        let importedIdentities = await window.importedSynchronizationTimelineIdentities()
        #expect(importedIdentities.count == 3)

        try await storage.closeForTesting()
        try await storage.closeForTesting()

        #expect(await storage.importedExternalSyncTimelineIDsForTesting().isEmpty)
        #expect(
            Set(await window.removedSynchronizationTimelineIdentities())
                == Set(importedIdentities)
        )
        #expect(await window.removedSynchronizationTimelineIdentities().count == 3)
        #expect(backend.destroyCount() == 1)
    }

    private func expectExplicitAcquireRejected(
        _ acquirePoint: WaylandGraphicsExternalSyncPoint
    ) async throws {
        let backend = ExternalReleaseTimelineTestBackend()
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed,
            surfaceFeedbackSynchronization: .explicitAvailable(version: 1)
        )
        let storage = externalBufferStorage(
            window: window,
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                fallbackPolicy: .requireGPU,
                synchronizationPolicy: .preferExplicit
            )
        )
        await storage.useFakeExternalReleaseTimelineForTesting(backend)

        let lease = try await storage.nextFrame()
        let buffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor()
        )
        let renderLease = try await lease.reserveExternalBuffer(buffer)
        await #expect(
            throws: WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable)
        ) {
            _ = try await renderLease.submit(
                acquireSynchronization: .drmSyncobj(acquirePoint)
            )
        }

        try await storage.closeForTesting()
    }
}

@Suite
struct ExternalBufferPresentationFeedbackTests {
    @Test
    func requestedPresentationFeedbackResolvesPresentedReceipt() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let submitted = try await registerAndSubmitTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor(),
            schedule: presentationFeedbackSchedule()
        )
        let identity = try #require(submitted.receipt.presentationFeedbackIdentity)

        #expect(identity.submissionID == submitted.receipt.id)
        #expect(identity.bufferID == submitted.buffer.id)
        #expect(
            await window.presentationFeedbackIdentitySnapshot() == [
                identity.surfacePresentationID
            ])
        #expect(
            await storage.externalPresentationFeedbackSnapshotForTesting()
                .pendingReceipts == 1
        )

        async let feedback = submitted.receipt.waitForPresentationFeedback()
        await window.emitPresentedFeedback(identity.surfacePresentationID)

        let result = await feedback
        guard
            case .presented(
                submissionID: let feedbackSubmissionID,
                bufferID: let feedbackBufferID,
                feedback: let presentation
            ) = result
        else {
            Issue.record("expected presented feedback result, got \(result)")
            return
        }
        #expect(feedbackSubmissionID == submitted.receipt.id)
        #expect(feedbackBufferID == submitted.buffer.id)
        #expect(presentation.surface == identity.surfacePresentationID)
        #expect(await submitted.receipt.waitForPresentationFeedback() == result)
        #expect(
            await storage.externalPresentationFeedbackSnapshotForTesting()
                .pendingReceipts == 0
        )

        try await storage.closeForTesting()
    }

    @Test
    func requestedPresentationFeedbackResolvesDiscardedReceipt() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let submitted = try await registerAndSubmitTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor(),
            schedule: presentationFeedbackSchedule()
        )
        let identity = try #require(submitted.receipt.presentationFeedbackIdentity)

        async let feedback = submitted.receipt.waitForPresentationFeedback()
        await window.emitDiscardedFeedback(identity.surfacePresentationID)

        #expect(
            await feedback
                == .discarded(
                    submissionID: submitted.receipt.id,
                    bufferID: submitted.buffer.id,
                    identity: identity.surfacePresentationID
                )
        )
        #expect(
            await storage.externalPresentationFeedbackSnapshotForTesting()
                .pendingReceipts == 0
        )

        try await storage.closeForTesting()
    }

    @Test
    func presentationFeedbackNotRequestedReturnsImmediately() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let submitted = try await registerAndSubmitTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor()
        )

        #expect(submitted.receipt.presentationFeedbackIdentity == nil)
        #expect(await submitted.receipt.waitForPresentationFeedback() == .notRequested)
        #expect(await window.presentationFeedbackIdentitySnapshot().isEmpty)
        #expect(
            await storage.externalPresentationFeedbackSnapshotForTesting()
                .pendingReceipts == 0
        )

        try await storage.closeForTesting()
    }

    @Test
    func backingCloseRetiresPendingPresentationFeedback() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let submitted = try await registerAndSubmitTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor(),
            schedule: presentationFeedbackSchedule()
        )
        let identity = try #require(submitted.receipt.presentationFeedbackIdentity)

        async let feedback = submitted.receipt.waitForPresentationFeedback()
        try await storage.closeForTesting()
        await window.emitPresentedFeedback(identity.surfacePresentationID)

        #expect(await feedback == .retired(.backingClosed))
        #expect(
            await storage.externalPresentationFeedbackSnapshotForTesting()
                .pendingReceipts == 0
        )
    }

    @Test
    func presentationFeedbackDoesNotMakeExternalBufferReusable() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let submitted = try await registerAndSubmitTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor(),
            schedule: presentationFeedbackSchedule()
        )
        let identity = try #require(submitted.receipt.presentationFeedbackIdentity)

        async let feedback = submitted.receipt.waitForPresentationFeedback()
        await window.emitPresentedFeedback(identity.surfacePresentationID)
        guard case .presented = await feedback else {
            Issue.record("expected presented feedback")
            return
        }

        let blockedLease = try await storage.nextFrame()
        do {
            _ = try await blockedLease.reserveExternalBuffer(submitted.buffer)
            Issue.record("presentation feedback must not release external buffer")
        } catch WaylandGraphicsError.externalBufferUnavailable {
            await blockedLease.cancel()
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        await window.emitImportedBufferRelease(at: 0)
        #expect(await submitted.receipt.waitForRelease() == .released)

        try await storage.closeForTesting()
    }
}

// swiftlint:disable type_body_length
@Suite
struct WaylandGraphicsExternalBufferLifecycleTests {
    @Test(.timeLimit(.minutes(1)))
    func backingCloseDoesNotJoinItsReentrantWindowCloseObserver() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        await window.setCloseObserver {
            await storage.closeBecauseWindowClosed()
        }

        try await storage.closeForTesting()

        #expect(try await window.isClosed)
        #expect(await window.closeRequests == 1)
    }

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
    func nextExternalFramePreservesObservedRuntimeStatus() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let firstLease = try await storage.nextFrame()

        _ = try await registerAndSubmitTestExternalBuffer(
            storage: storage,
            lease: firstLease,
            descriptor: try testExternalDescriptor()
        )
        let secondLease = try await storage.nextFrame()

        #expect(secondLease.runtimePath.backing == .active)
        #expect(secondLease.runtimePath.dmabuf == .active)
        #expect(secondLease.runtimePath.dmabufImport == .active)
        #expect(secondLease.runtimePath.bufferLifecycle == .active)
        await secondLease.cancel()

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
        // swiftlint:disable:next no_unstructured_task
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
    func externalBufferPoolStressDrainsToQuiescence() async throws {
        let frameCount = 1_000
        let poolSize = 3
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(
            window: window,
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                fallbackPolicy: .requireGPU,
                synchronizationPolicy: .implicitOnly
            )
        )
        let registrationLease = try await storage.nextFrame()
        var buffers: [WaylandGraphicsExternalBuffer] = []
        for _ in 0..<poolSize {
            let buffer = try await registerTestExternalBuffer(
                storage: storage,
                lease: registrationLease,
                descriptor: try testExternalDescriptor()
            )
            buffers.append(buffer)
        }
        await registrationLease.cancel()

        var terminalReleaseCount = 0
        var reuseCount = 0
        for frameIndex in 0..<frameCount {
            let bufferIndex = frameIndex % poolSize
            let lease = try await storage.nextFrame()
            let renderLease = try await lease.reserveExternalBuffer(buffers[bufferIndex])
            let receipt = try await renderLease.submit()
            await window.emitImportedBufferRelease(at: bufferIndex)
            #expect(await receipt.waitForRelease() == .released)
            terminalReleaseCount += 1
            if frameIndex >= poolSize {
                reuseCount += 1
            }
        }

        for buffer in buffers {
            try await storage.unregisterExternalBuffer(buffer)
        }

        #expect(await window.importRequests == poolSize)
        #expect(await window.submitConstraintsSnapshot().count == frameCount)
        #expect(terminalReleaseCount == frameCount)
        #expect(reuseCount == frameCount - poolSize)
        #expect(await storage.externalBufferLifecycleSnapshotForTesting().total == 0)
        #expect(await storage.externalBufferLifecycleSnapshotForTesting().releaseTimelines == 0)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting().isEmpty)
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)
        #expect(await storage.externalReleaseSnapshotForTesting().pendingReceipts == 0)
        #expect(await storage.externalReleaseSnapshotForTesting().activeMonitors == 0)

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
        // swiftlint:disable:next no_unstructured_task
        let release = Task {
            await submitted.receipt.waitForRelease()
        }

        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting() == [0])

        try await storage.closeForTesting()
        await window.emitImportedBufferRelease(at: 0)

        #expect(await release.value == .retired(.backingClosed))
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

        #expect(receipt.releaseMechanism == .implicitWaylandBufferRelease)
        #expect(receipt.releaseSynchronization == .implicitWaylandBufferRelease)
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
    func frameLeaseCancelReleasesReservedExternalBuffer() async throws {
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

        _ = try await firstLease.reserveExternalBuffer(buffer)
        await firstLease.cancel()

        let secondLease = try await storage.nextFrame()
        _ = try await secondLease.reserveExternalBuffer(buffer)
        await secondLease.cancel()

        try await storage.closeForTesting()
    }

    @Test
    func frameLeaseCannotReserveMultipleExternalBuffers() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let firstBuffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor()
        )
        let secondBuffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor()
        )

        _ = try await lease.reserveExternalBuffer(firstBuffer)
        await #expect(throws: (any Error).self) {
            _ = try await lease.reserveExternalBuffer(secondBuffer)
        }
        await lease.cancel()

        try await storage.closeForTesting()
    }

    @Test
    func failedSoftwareSubmitReleasesExternalBufferReservation() async throws {
        let window = try ExternalBufferFakeManagedWindow(importBehavior: .succeed)
        let storage = externalBufferStorage(window: window)
        let firstLease = try await storage.nextFrame()
        let buffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: firstLease,
            descriptor: try testExternalDescriptor()
        )

        _ = try await firstLease.reserveExternalBuffer(buffer)
        await #expect(
            throws: WaylandGraphicsError.unavailable(.managedGPUSubmissionUnavailable)
        ) {
            try await firstLease.submitSoftware { _ in
                Issue.record("unexpected software draw")
            }
        }

        let secondLease = try await storage.nextFrame()
        _ = try await secondLease.reserveExternalBuffer(buffer)
        await secondLease.cancel()

        try await storage.closeForTesting()
    }

    @Test
    func staleRenderLeaseCancelDoesNotClearNewReservation() async throws {
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

        let firstRenderLease = try await firstLease.reserveExternalBuffer(buffer)
        let firstReceipt = try await firstRenderLease.submit()
        await window.emitImportedBufferRelease(at: 0)
        #expect(await firstReceipt.waitForRelease() == .released)

        let secondLease = try await storage.nextFrame()
        let secondRenderLease = try await secondLease.reserveExternalBuffer(buffer)
        await firstRenderLease.cancel()
        _ = try await secondRenderLease.submit()

        try await storage.closeForTesting()
    }

    @Test
    func cancelDuringExternalSubmitDoesNotClearSubmission() async throws {
        let hook = ExternalBufferPresentationHook()
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed
        ) {
            await hook.run()
        }
        let storage = externalBufferStorage(window: window)
        let lease = try await storage.nextFrame()
        let buffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor(
                modifier: WaylandGraphicsDRMFormatModifier.linear.rawValue,
                offset: 0,
                fd: testOwnedFileDescriptor()
            )
        )

        let renderLease = try await lease.reserveExternalBuffer(buffer)
        await hook.set { await renderLease.cancel() }
        let receipt = try await renderLease.submit()

        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting() == [0])
        await window.emitImportedBufferRelease(at: 0)
        #expect(await receipt.waitForRelease() == .released)

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
    func failedSubmitCleansRetiringTimeline() async throws {
        let backend = ExternalReleaseTimelineTestBackend()
        let presentationHook = ExternalBufferPresentationHook()
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed,
            presentationFailuresBeforeSuccess: 1,
            surfaceFeedbackSynchronization: .explicitAvailable(version: 1)
        ) {
            await presentationHook.run()
        }
        let storage = externalBufferStorage(
            window: window,
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                fallbackPolicy: .requireGPU,
                synchronizationPolicy: .preferExplicit
            )
        )
        await storage.useFakeExternalReleaseTimelineForTesting(backend)

        let lease = try await storage.nextFrame()
        let buffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor(
                modifier: WaylandGraphicsDRMFormatModifier.linear.rawValue,
                offset: 0,
                fd: testOwnedFileDescriptor()
            )
        )
        let importedTimelineCount =
            await window.importedSynchronizationTimelineIdentities().count
        #expect(importedTimelineCount == 1)

        await presentationHook.set {
            await storage.markExternalBufferStaleForTesting(buffer)
            await window.emitImportedBufferRelease(at: 0)
        }

        let renderLease = try await lease.reserveExternalBuffer(buffer)
        do {
            _ = try await renderLease.submit()
            Issue.record("expected external buffer commit failure")
        } catch WaylandGraphicsError.unavailable(.commitFailed) {
            #expect(
                await window.removedSynchronizationTimelineCountReaches(
                    importedTimelineCount
                )
            )
            #expect(backend.destroyCount() == 1)
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting().isEmpty)

        try await storage.closeForTesting()
    }

    @Test
    func explicitSubmitReleasesAfterFakeTimelineSignal() async throws {
        let backend = ExternalReleaseTimelineTestBackend(defaultState: .pending)
        let fixture = try await explicitReleaseSubmissionFixture(backend: backend)
        let storage = fixture.storage
        let buffer = fixture.buffer
        let receipt = fixture.receipt
        let acquireTimeline = fixture.acquireTimeline

        #expect(receipt.releaseMechanism == .explicitSyncobjTimelinePoint)
        let firstReleasePoint = try #require(explicitReleasePoint(from: receipt))
        #expect(firstReleasePoint.timelineID.rawValue == 1)
        #expect(firstReleasePoint.point == 1)
        #expect(
            await storage.externalBufferLifecycleSnapshotForTesting().submitted == 1
        )
        #expect(await storage.externalReleaseSnapshotForTesting().pendingReceipts == 1)
        #expect(await storage.externalReleaseSnapshotForTesting().activeMonitors == 1)

        let blockedLease = try await storage.nextFrame()
        do {
            _ = try await blockedLease.reserveExternalBuffer(buffer)
            Issue.record("release facts must not make a submitted buffer reusable")
        } catch WaylandGraphicsError.externalBufferUnavailable {
            await blockedLease.cancel()
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        async let firstRelease = receipt.waitForRelease()
        async let secondRelease = receipt.waitForRelease()
        backend.signal(1)
        let releases = await (firstRelease, secondRelease)

        #expect(releases.0 == .released)
        #expect(releases.1 == .released)
        #expect(await storage.externalBufferLifecycleSnapshotForTesting().available == 1)
        #expect(await storage.externalReleaseSnapshotForTesting().pendingReceipts == 0)
        #expect(await storage.externalReleaseSnapshotForTesting().activeMonitors == 0)

        let reuseLease = try await storage.nextFrame()
        let reuseRenderLease = try await reuseLease.reserveExternalBuffer(buffer)
        let reuseReceipt = try await reuseRenderLease.submit(
            acquireSynchronization: .drmSyncobj(try acquireTimeline.point(2))
        )
        let secondReleasePoint = try #require(explicitReleasePoint(from: reuseReceipt))
        #expect(secondReleasePoint.timelineID == firstReleasePoint.timelineID)
        #expect(secondReleasePoint.point == 2)
        backend.signal(2)
        #expect(await reuseReceipt.waitForRelease() == .released)

        try await storage.unregisterExternalBuffer(buffer)
        #expect(await storage.externalBufferLifecycleSnapshotForTesting().total == 0)
        #expect(await storage.externalBufferLifecycleSnapshotForTesting().releaseTimelines == 0)
        #expect(backend.destroyCount() == 1)

        try await storage.closeForTesting()
    }

    @Test
    func explicitReleaseFailureRetiresBackingAndPoisonsSlot() async throws {
        let backend = ExternalReleaseTimelineTestBackend(defaultState: .pending)
        let fixture = try await explicitReleaseSubmissionFixture(backend: backend)
        let storage = fixture.storage
        let buffer = fixture.buffer
        let receipt = fixture.receipt
        let window = fixture.window
        let releasePoint = try #require(explicitReleasePoint(from: receipt))
        #expect(releasePoint.point == 1)
        let blockedLease = try await storage.nextFrame()
        await window.setCloseObserver {
            await storage.closeBecauseWindowClosed()
        }
        backend.fail(1)

        #expect(await receipt.waitForRelease() == .failed(.explicitSyncReleaseFailed))
        let runtimePath = await storage.runtimePathSnapshotForTesting()
        #expect(runtimePath.backing == .failed(.explicitSyncReleaseFailed))
        #expect(runtimePath.dmabufImport == .failed(.explicitSyncReleaseFailed))
        #expect(runtimePath.bufferLifecycle == .failed(.explicitSyncReleaseFailed))
        #expect(runtimePath.explicitSync == .failed(.explicitSyncReleaseFailed))
        #expect(await storage.externalBufferLifecycleSnapshotForTesting().total == 0)
        #expect(await storage.externalReleaseSnapshotForTesting().pendingReceipts == 0)
        #expect(await storage.externalReleaseSnapshotForTesting().activeMonitors == 0)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting().isEmpty)
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)
        #expect(try await window.isClosed)
        #expect(await window.closeRequests == 1)
        #expect(backend.destroyCount() == 1)
        #expect(await window.removedSynchronizationTimelineIdentities().count == 2)

        do {
            _ = try await blockedLease.reserveExternalBuffer(buffer)
            Issue.record("release tracking failure must prevent buffer reuse")
        } catch WaylandGraphicsError.backingClosed {
            // Expected terminal backing state.
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        do {
            try await storage.unregisterExternalBuffer(buffer)
            Issue.record("release tracking failure must retire registrations")
        } catch WaylandGraphicsError.backingClosed {
            // Automatic backing retirement defines unregister after tracking loss.
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        await window.emitImportedBufferRelease(at: 0)
        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting().isEmpty)
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)

        try await storage.closeForTesting()
        #expect(await window.closeRequests == 1)
        #expect(backend.destroyCount() == 1)
        #expect(await window.removedSynchronizationTimelineIdentities().count == 2)
    }

    @Test
    func explicitReleaseMonitorRetainsBackingUntilFailureCleanup() async throws {
        let backend = ExternalReleaseTimelineTestBackend(defaultState: .pending)
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed,
            surfaceFeedbackSynchronization: .explicitAvailable(version: 1)
        )
        let receipt: WaylandGraphicsExternalBufferSubmissionReceipt
        weak var retainedStorage: WaylandGraphicsWindowBackingStorage?
        do {
            let storage = externalBufferStorage(
                window: window,
                configuration: WaylandGraphicsConfiguration(
                    presentationMode: .externalGPU,
                    fallbackPolicy: .requireGPU,
                    synchronizationPolicy: .preferExplicit
                )
            )
            retainedStorage = storage
            await storage.useFakeExternalReleaseTimelineForTesting(backend)
            let lease = try await storage.nextFrame()
            let buffer = try await registerTestExternalBuffer(
                storage: storage,
                lease: lease,
                descriptor: try testExternalDescriptor()
            )
            let acquireTimeline = try await storage.importExternalSyncTimeline(
                testOwnedFileDescriptor()
            )
            let renderLease = try await lease.reserveExternalBuffer(buffer)
            receipt = try await renderLease.submit(
                acquireSynchronization: .drmSyncobj(try acquireTimeline.point(1))
            )
        }

        try #require(retainedStorage != nil)
        backend.fail(1)
        #expect(await receipt.waitForRelease() == .failed(.explicitSyncReleaseFailed))
        #expect(try await window.isClosed)
        #expect(await window.closeRequests == 1)

        for _ in 0..<10 where retainedStorage != nil {
            await Task.yield()
        }
        #expect(retainedStorage == nil)
    }

    @Test
    func releaseTrackingFailureRetiresOtherPendingResourcesOnce() async throws {
        let backend = ExternalReleaseTimelineTestBackend(defaultState: .pending)
        let fixture = try await pendingReleaseAuthorityLossFixture(backend: backend)
        let storage = fixture.storage
        let window = fixture.window
        let explicitReceipt = fixture.explicitReceipt
        let implicitReceipt = fixture.implicitReceipt
        #expect(implicitReceipt.releaseMechanism == .implicitWaylandBufferRelease)

        async let explicitRelease = explicitReceipt.waitForRelease()
        async let implicitRelease = implicitReceipt.waitForRelease()
        async let implicitPresentation = implicitReceipt.waitForPresentationFeedback()
        backend.fail(1)

        #expect(await explicitRelease == .failed(.explicitSyncReleaseFailed))
        #expect(await implicitRelease == .retired(.backingClosed))
        #expect(await implicitPresentation == .retired(.backingClosed))
        #expect(
            await explicitReceipt.waitForRelease()
                == .failed(.explicitSyncReleaseFailed)
        )
        #expect(
            await implicitReceipt.waitForRelease()
                == .retired(.backingClosed)
        )
        #expect(await storage.externalBufferLifecycleSnapshotForTesting().total == 0)
        #expect(await storage.externalReleaseSnapshotForTesting().pendingReceipts == 0)
        #expect(await storage.externalReleaseSnapshotForTesting().activeMonitors == 0)
        #expect(
            await storage.externalPresentationFeedbackSnapshotForTesting().pendingReceipts == 0
        )
        #expect(await window.closeRequests == 1)
        #expect(backend.destroyCount() == 2)
        #expect(await window.removedSynchronizationTimelineIdentities().count == 3)

        try await storage.closeForTesting()
        #expect(await window.closeRequests == 1)
        #expect(backend.destroyCount() == 2)
        #expect(await window.removedSynchronizationTimelineIdentities().count == 3)
    }

    @Test
    func closeRetiresPendingExplicitReleaseAndIgnoresLateSignal() async throws {
        let backend = ExternalReleaseTimelineTestBackend(defaultState: .pending)
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed,
            surfaceFeedbackSynchronization: .explicitAvailable(version: 1)
        )
        let storage = externalBufferStorage(
            window: window,
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                fallbackPolicy: .requireGPU,
                synchronizationPolicy: .preferExplicit
            )
        )
        await storage.useFakeExternalReleaseTimelineForTesting(backend)

        let lease = try await storage.nextFrame()
        let buffer = try await registerTestExternalBuffer(
            storage: storage,
            lease: lease,
            descriptor: try testExternalDescriptor()
        )
        let acquireTimeline = try await storage.importExternalSyncTimeline(
            testOwnedFileDescriptor()
        )
        let renderLease = try await lease.reserveExternalBuffer(buffer)
        let receipt = try await renderLease.submit(
            acquireSynchronization: .drmSyncobj(try acquireTimeline.point(1))
        )

        async let release = receipt.waitForRelease()
        try await storage.closeForTesting()
        backend.signal(1)

        #expect(await release == .retired(.backingClosed))
        #expect(await storage.externalBufferLifecycleSnapshotForTesting().total == 0)
        #expect(await storage.externalReleaseSnapshotForTesting().pendingReceipts == 0)
        #expect(await storage.externalReleaseSnapshotForTesting().activeMonitors == 0)
    }

    @Test
    func submittedStaleRegisteredBufferRetiresAfterRelease() async throws {
        let window = try ExternalBufferFakeManagedWindow(
            importBehavior: .succeed,
            surfaceFeedbackSynchronization: .explicitAvailable(version: 1)
        )
        let storage = externalBufferStorage(
            window: window,
            configuration: WaylandGraphicsConfiguration(
                presentationMode: .externalGPU,
                fallbackPolicy: .requireGPU,
                synchronizationPolicy: .preferExplicit
            )
        )
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
        let importedTimelineCount =
            await window.importedSynchronizationTimelineIdentities().count
        await unregisterIfAvailable(storage: storage, buffer: buffer)
        if importedTimelineCount > 0 {
            #expect(
                await window.removedSynchronizationTimelineCountReaches(
                    importedTimelineCount
                )
            )
        }
        for _ in 0..<10 {
            if await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty {
                break
            }
            await Task.yield()
        }

        #expect(await storage.externalBufferSubmittedSlotRawValuesForTesting().isEmpty)
        #expect(await storage.externalBufferAvailableSlotRawValuesForTesting().isEmpty)

        await expectExternalBufferUnavailable {
            _ = try await secondLease.reserveExternalBuffer(buffer)
        }
        await secondLease.cancel()

        try await storage.closeForTesting()
    }

    private func expectExternalBufferUnavailable(
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("expected external buffer to be unavailable")
        } catch WaylandGraphicsError.externalBufferUnavailable {
            // Expected.
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    private func unregisterIfAvailable(
        storage: WaylandGraphicsWindowBackingStorage,
        buffer: WaylandGraphicsExternalBuffer
    ) async {
        do {
            try await storage.unregisterExternalBuffer(buffer)
        } catch WaylandGraphicsError.externalBufferUnavailable {
            // The notifier may have already retired the stale buffer.
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}
// swiftlint:enable type_body_length

private actor ExternalBufferPresentationHook {
    private var operation: (@Sendable () async -> Void)?

    func set(_ presentationOperation: @escaping @Sendable () async -> Void) {
        operation = presentationOperation
    }

    func run() async {
        guard let operation else { return }

        await operation()
    }
}

private actor ExternalImportBarrier {
    private var isSuspended = false
    private var isResumed = false
    private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeWaiters: [CheckedContinuation<Void, Never>] = []

    func suspend() async {
        isSuspended = true
        let waiters = suspensionWaiters
        suspensionWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
        guard !isResumed else { return }

        await withCheckedContinuation { continuation in
            resumeWaiters.append(continuation)
        }
    }

    func waitUntilSuspended() async {
        guard !isSuspended else { return }

        await withCheckedContinuation { continuation in
            suspensionWaiters.append(continuation)
        }
    }

    func resume() {
        isResumed = true
        let waiters = resumeWaiters
        resumeWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private final class ExternalBufferDestroyRecorder: Sendable {
    private let countStorage = Mutex(0)

    var count: Int {
        countStorage.withLock { $0 }
    }

    func recordDestroy() {
        countStorage.withLock { $0 += 1 }
    }
}

private struct ExternalImportTestHooks: Sendable {
    let bufferBarrier: ExternalImportBarrier?
    let timelineBarrier: ExternalImportBarrier?
    let destroyRecorder: ExternalBufferDestroyRecorder?

    init(
        bufferBarrier: ExternalImportBarrier? = nil,
        timelineBarrier: ExternalImportBarrier? = nil,
        destroyRecorder: ExternalBufferDestroyRecorder? = nil
    ) {
        self.bufferBarrier = bufferBarrier
        self.timelineBarrier = timelineBarrier
        self.destroyRecorder = destroyRecorder
    }
}

private actor ExternalBufferFakeManagedWindow: WaylandGraphicsManagedWindow {
    enum ImportBehavior: Sendable {
        case fail
        case clientFailure
        case succeed
    }

    nonisolated let id: WindowID
    private var geometryValue: SurfaceGeometry
    private let importBehavior: ImportBehavior
    private var presentationFailuresBeforeSuccess: Int
    private var nextGeneration: UInt64 = 1
    private(set) var importRequests = 0
    private(set) var closeRequests = 0
    private var isWindowClosed = false
    private var closeObserver: (@Sendable () async -> Void)?
    private var importedBuffers: [RawLinuxDmabufBuffer] = []
    private var submitConstraints: [SurfaceSubmitConstraints] = []
    private var submittedMetadata: [SurfaceCommitMetadata] = []
    private var presentationFeedbackRequests: [Bool] = []
    private var presentationFeedbackIdentities: [SurfacePresentationIdentity] = []
    private var presentationFeedbackHandlers:
        [SurfacePresentationIdentity: @Sendable (SurfacePresentationFeedback) -> Void] = [:]
    private var nextPresentationFeedbackIdentityRawValue: UInt64 = 1
    private(set) var preparePresentationRequests = 0
    private var importedSyncTimelineIdentities: [SurfaceSyncTimelineIdentity] = []
    private var removedSyncTimelineIdentities: [SurfaceSyncTimelineIdentity] = []
    private let surfaceFeedbackSynchronization: SurfaceSynchronizationCapability?
    private let includeDistinctDuplicateSurfaceFeedback: Bool
    private let presentationHook: (@Sendable () async -> Void)?
    private let importHooks: ExternalImportTestHooks

    init(
        windowID backingWindowID: WindowID = WindowID(rawValue: 910),
        importBehavior requestedImportBehavior: ImportBehavior = .fail,
        presentationFailuresBeforeSuccess requestedPresentationFailures: Int = 0,
        surfaceFeedbackSynchronization requestedSurfaceFeedbackSynchronization:
            SurfaceSynchronizationCapability? = .implicitOnly,
        includeDistinctDuplicateSurfaceFeedback includeDistinctFeedbackDuplicates:
            Bool = false,
        presentationHook requestedPresentationHook: (@Sendable () async -> Void)? = nil,
        importHooks requestedImportHooks: ExternalImportTestHooks = ExternalImportTestHooks()
    ) throws {
        id = backingWindowID
        geometryValue = try testGraphicsSurfaceGeometry()
        importBehavior = requestedImportBehavior
        presentationFailuresBeforeSuccess = requestedPresentationFailures
        surfaceFeedbackSynchronization = requestedSurfaceFeedbackSynchronization
        includeDistinctDuplicateSurfaceFeedback = includeDistinctFeedbackDuplicates
        presentationHook = requestedPresentationHook
        importHooks = requestedImportHooks
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
        if let barrier = importHooks.bufferBarrier {
            await barrier.suspend()
        }
        switch importBehavior {
        case .fail:
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        case .clientFailure:
            throw ClientError.display(.presentationTimeUnavailable)
        case .succeed:
            let buffer = try testRawLinuxDmabufBuffer(
                pointer: UInt(0xE0_000 + importRequests),
                destroyRecorder: importHooks.destroyRecorder
            )
            importedBuffers.append(buffer)
            return buffer
        }
    }

    func importGraphicsPreviewSynchronizationTimeline(
        _ fileDescriptor: inout RawDrmSyncobjTimelineFD,
        identity: SurfaceSyncTimelineIdentity
    ) async throws {
        fileDescriptor.close()
        importedSyncTimelineIdentities.append(identity)
        if let barrier = importHooks.timelineBarrier {
            await barrier.suspend()
        }
    }

    func removeGraphicsPreviewSynchronizationTimeline(
        identity: SurfaceSyncTimelineIdentity
    ) async throws {
        removedSyncTimelineIdentities.append(identity)
    }

    func removedSynchronizationTimelineIdentities() -> [SurfaceSyncTimelineIdentity] {
        removedSyncTimelineIdentities
    }

    func importedSynchronizationTimelineIdentities() -> [SurfaceSyncTimelineIdentity] {
        importedSyncTimelineIdentities
    }

    func removedSynchronizationTimelineCountReaches(_ count: Int) async -> Bool {
        for _ in 0..<10 {
            if removedSyncTimelineIdentities.count == count {
                return true
            }
            await Task.yield()
        }

        return removedSyncTimelineIdentities.count == count
    }

    func presentGraphicsPreviewBuffer(
        _ buffer: RawSurfaceBuffer,
        submitConstraints submittedConstraints: SurfaceSubmitConstraints,
        metadata submittedFrameMetadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        presentationFeedbackHandler:
            (@Sendable (SurfacePresentationFeedback) -> Void)?
    ) async throws -> PreviewBufferPresentationResult {
        _ = buffer
        guard !isWindowClosed else {
            throw WaylandGraphicsError.windowClosed
        }

        if let presentationHook {
            await presentationHook()
        }

        submitConstraints.append(submittedConstraints)
        submittedMetadata.append(submittedFrameMetadata)
        presentationFeedbackRequests.append(requestPresentationFeedback)

        guard presentationFailuresBeforeSuccess == 0 else {
            presentationFailuresBeforeSuccess -= 1
            throw WaylandGraphicsError.unavailable(.commitFailed)
        }

        let presentationFeedbackIdentity: SurfacePresentationIdentity?
        if requestPresentationFeedback {
            let identity = SurfacePresentationIdentity(
                rawValue: nextPresentationFeedbackIdentityRawValue
            )
            nextPresentationFeedbackIdentityRawValue += 1
            presentationFeedbackIdentities.append(identity)
            if let presentationFeedbackHandler {
                presentationFeedbackHandlers[identity] = presentationFeedbackHandler
            }
            presentationFeedbackIdentity = identity
        } else {
            presentationFeedbackIdentity = nil
        }

        defer { nextGeneration += 1 }
        return try testPreviewBufferPresentationResult(
            generation: nextGeneration,
            presentationFeedbackIdentity: presentationFeedbackIdentity
        )
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

    func presentationFeedbackIdentitySnapshot() -> [SurfacePresentationIdentity] {
        presentationFeedbackIdentities
    }

    func pendingPresentationFeedbackHandlerCount() -> Int {
        presentationFeedbackHandlers.count
    }

    func emitPresentedFeedback(_ identity: SurfacePresentationIdentity) {
        guard let handler = presentationFeedbackHandlers.removeValue(forKey: identity)
        else { return }

        handler(
            .presented(
                PresentationFeedback(
                    surface: identity,
                    timestamp: PresentationTimestamp(seconds: 1, nanoseconds: 2),
                    refreshNanoseconds: 16_666_666,
                    sequence: PresentationSequence(value: 3),
                    flags: [.vsync],
                    synchronizedOutput: nil
                )
            )
        )
    }

    func emitDiscardedFeedback(_ identity: SurfacePresentationIdentity) {
        presentationFeedbackHandlers.removeValue(forKey: identity)?(.discarded(identity))
    }

    func emitImportedBufferRelease(at index: Int) {
        guard importedBuffers.indices.contains(index) else { return }

        importedBuffers[index].emitReleaseForTesting()
    }

    func setCloseObserver(_ observer: @escaping @Sendable () async -> Void) {
        closeObserver = observer
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
        closeRequests += 1
        isWindowClosed = true
        let observer = closeObserver
        closeObserver = nil
        await observer?()
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

private func presentationFeedbackSchedule() -> WaylandGraphicsFrameSchedule {
    WaylandGraphicsFrameSchedule(presentationFeedback: .requestWhenAvailable)
}

private struct ExplicitReleaseSubmissionFixture {
    let window: ExternalBufferFakeManagedWindow
    let storage: WaylandGraphicsWindowBackingStorage
    let buffer: WaylandGraphicsExternalBuffer
    let acquireTimeline: WaylandGraphicsExternalSyncTimeline
    let receipt: WaylandGraphicsExternalBufferSubmissionReceipt
}

private func explicitReleaseSubmissionFixture(
    backend: ExternalReleaseTimelineTestBackend
) async throws -> ExplicitReleaseSubmissionFixture {
    let window = try ExternalBufferFakeManagedWindow(
        importBehavior: .succeed,
        surfaceFeedbackSynchronization: .explicitAvailable(version: 1)
    )
    let storage = externalBufferStorage(
        window: window,
        configuration: WaylandGraphicsConfiguration(
            presentationMode: .externalGPU,
            fallbackPolicy: .requireGPU,
            synchronizationPolicy: .preferExplicit
        )
    )
    await storage.useFakeExternalReleaseTimelineForTesting(backend)

    let lease = try await storage.nextFrame()
    let buffer = try await registerTestExternalBuffer(
        storage: storage,
        lease: lease,
        descriptor: try testExternalDescriptor()
    )
    let acquireTimeline = try await storage.importExternalSyncTimeline(
        testOwnedFileDescriptor()
    )
    let renderLease = try await lease.reserveExternalBuffer(buffer)
    let receipt = try await renderLease.submit(
        acquireSynchronization: .drmSyncobj(try acquireTimeline.point(1))
    )
    return ExplicitReleaseSubmissionFixture(
        window: window,
        storage: storage,
        buffer: buffer,
        acquireTimeline: acquireTimeline,
        receipt: receipt
    )
}

private struct PendingReleaseAuthorityLossFixture {
    let window: ExternalBufferFakeManagedWindow
    let storage: WaylandGraphicsWindowBackingStorage
    let explicitReceipt: WaylandGraphicsExternalBufferSubmissionReceipt
    let implicitReceipt: WaylandGraphicsExternalBufferSubmissionReceipt
}

private func pendingReleaseAuthorityLossFixture(
    backend: ExternalReleaseTimelineTestBackend
) async throws -> PendingReleaseAuthorityLossFixture {
    let window = try ExternalBufferFakeManagedWindow(
        importBehavior: .succeed,
        surfaceFeedbackSynchronization: .explicitAvailable(version: 1)
    )
    let storage = externalBufferStorage(
        window: window,
        configuration: WaylandGraphicsConfiguration(
            presentationMode: .externalGPU,
            fallbackPolicy: .requireGPU,
            synchronizationPolicy: .preferExplicit
        )
    )
    await storage.useFakeExternalReleaseTimelineForTesting(backend)

    let firstLease = try await storage.nextFrame()
    let explicitBuffer = try await registerTestExternalBuffer(
        storage: storage,
        lease: firstLease,
        descriptor: try testExternalDescriptor()
    )
    let implicitBuffer = try await registerTestExternalBuffer(
        storage: storage,
        lease: firstLease,
        descriptor: try testExternalDescriptor()
    )
    let acquireTimeline = try await storage.importExternalSyncTimeline(
        testOwnedFileDescriptor()
    )
    let explicitRenderLease = try await firstLease.reserveExternalBuffer(explicitBuffer)
    let explicitReceipt = try await explicitRenderLease.submit(
        acquireSynchronization: .drmSyncobj(try acquireTimeline.point(1))
    )

    let secondLease = try await storage.nextFrame()
    let implicitRenderLease = try await secondLease.reserveExternalBuffer(implicitBuffer)
    let implicitReceipt = try await implicitRenderLease.submit(
        schedule: presentationFeedbackSchedule()
    )
    return PendingReleaseAuthorityLossFixture(
        window: window,
        storage: storage,
        explicitReceipt: explicitReceipt,
        implicitReceipt: implicitReceipt
    )
}

private func explicitReleasePoint(
    from receipt: WaylandGraphicsExternalBufferSubmissionReceipt
) -> WaylandGraphicsExternalSyncobjTimelinePoint? {
    guard
        case .explicitSyncobjTimelinePoint(
            let releasePoint,
            compositorAccepted: let compositorAccepted
        ) = receipt.releaseSynchronization
    else {
        Issue.record("expected explicit release synchronization facts")
        return nil
    }

    #expect(compositorAccepted)
    return releasePoint
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

private func testRawLinuxDmabufBuffer(
    pointer rawPointer: UInt,
    destroyRecorder: ExternalBufferDestroyRecorder? = nil
) throws -> RawLinuxDmabufBuffer {
    let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))
    return unsafe RawLinuxDmabufBuffer(testingPointer: pointer) {
        destroyRecorder?.recordDestroy()
    }
}

private func testPreviewBufferPresentationResult(
    generation: UInt64,
    presentationFeedbackIdentity: SurfacePresentationIdentity? = nil
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
        ),
        presentationFeedbackIdentity: presentationFeedbackIdentity
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
