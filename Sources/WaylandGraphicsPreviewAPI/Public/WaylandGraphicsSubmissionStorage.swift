import Foundation
import Glibc
import WaylandClient
import WaylandGPUPreview
import WaylandGraphicsCore
import WaylandRaw

// swiftlint:disable file_length
// SAFETY: Access to the syncobj timeline and destroy flag is serialized by
// lock because explicit release polling can run concurrently with unregister
// or backing-close cleanup.
private final class WaylandGraphicsExternalReleaseTimeline: @unchecked Sendable {
    static let pollSleepNanoseconds: UInt64 = 10_000_000

    let identity: GPUSyncTimeline
    private let lock = NSLock()
    private let deviceFileDescriptor: Int32
    private let timeline: DRMSyncobjTimeline
    private var isDestroyed = false

    init(
        renderNode: WaylandGraphicsRenderNode,
        identity timelineIdentity: GPUSyncTimeline
    ) throws {
        guard let path = renderNode.path else {
            throw WaylandGraphicsError.unavailable(.noRenderNode)
        }

        let fileDescriptor = unsafe path.withCString { pathPointer in
            unsafe Glibc.open(pathPointer, O_RDWR | O_CLOEXEC)
        }
        guard fileDescriptor >= 0 else {
            throw WaylandGraphicsError.unavailable(.noRenderNode)
        }

        do {
            timeline = try DRMSyncobjTimeline(deviceFileDescriptor: fileDescriptor)
            deviceFileDescriptor = fileDescriptor
            identity = timelineIdentity
        } catch {
            Glibc.close(fileDescriptor)
            throw WaylandGraphicsError.unavailable(.explicitSyncSetupFailed)
        }
    }

    func exportFileDescriptor() throws -> RawDrmSyncobjTimelineFD {
        lock.lock()
        defer { lock.unlock() }
        guard !isDestroyed else {
            throw WaylandGraphicsError.unavailable(.explicitSyncSetupFailed)
        }

        do {
            return try timeline.exportFileDescriptor()
        } catch {
            throw WaylandGraphicsError.unavailable(.explicitSyncSetupFailed)
        }
    }

    func releasePointIsSignaled(_ point: RawSyncobjTimelinePoint) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isDestroyed else {
            throw WaylandGraphicsError.unavailable(.explicitSyncReleaseFailed)
        }

        do {
            try timeline.wait(
                point,
                timeoutNanoseconds: 0,
                waitForSubmit: true
            )
            return true
        } catch let error where error.isSyncobjTimelineWaitTimeout {
            return false
        } catch {
            throw WaylandGraphicsError.unavailable(.explicitSyncReleaseFailed)
        }
    }

    func destroy() {
        lock.lock()
        defer { lock.unlock() }
        guard !isDestroyed else {
            return
        }

        isDestroyed = true
        timeline.destroy()
        Glibc.close(deviceFileDescriptor)
    }

    deinit {
        destroy()
    }
}

private struct ExternalBufferConfigurationFact: Equatable, Sendable {
    let format: WaylandGraphicsDRMFormat
    let modifier: WaylandGraphicsDRMFormatModifier
    let renderNode: WaylandGraphicsRenderNode
    let alphaMode: WaylandGraphicsExternalAlphaMode
    let scanoutPreferred: Bool
}

private struct ExternalBufferRegistryState: Sendable {
    private(set) var entries: [WaylandGraphicsExternalBufferID: Entry] = [:]

    struct Entry: Sendable {
        let handle: WaylandGraphicsExternalBuffer
        let explicitReleaseTimeline: WaylandGraphicsExternalReleaseTimeline?
        var nextExplicitReleasePoint: UInt64 = 1
        var lifecycle = Lifecycle.available
    }

    enum Lifecycle: Sendable {
        case available
        case reserved(WaylandGraphicsFrameLeaseID)
        case inCompositorUse(WaylandGraphicsExternalSubmissionID)
        case retiring(RetirementReason, WaylandGraphicsExternalSubmissionID?)
    }

    enum RetirementReason: Sendable {
        case explicitUnregister
        case staleContract
        case backingClose
        case windowClose
        case releaseTrackingFailure
    }

    func entry(for bufferID: WaylandGraphicsExternalBufferID) -> Entry? {
        entries[bufferID]
    }

    mutating func insert(
        handle: WaylandGraphicsExternalBuffer,
        explicitReleaseTimeline: WaylandGraphicsExternalReleaseTimeline?
    ) {
        entries[handle.id] = Entry(
            handle: handle,
            explicitReleaseTimeline: explicitReleaseTimeline
        )
    }

    @discardableResult
    mutating func removeValue(
        for bufferID: WaylandGraphicsExternalBufferID
    ) -> Entry? {
        entries.removeValue(forKey: bufferID)
    }

    mutating func removeAll() {
        entries.removeAll()
    }

    func reservation(
        for bufferID: WaylandGraphicsExternalBufferID
    ) -> WaylandGraphicsFrameLeaseID? {
        guard case .reserved(let leaseID) = entries[bufferID]?.lifecycle else {
            return nil
        }

        return leaseID
    }

    func leaseHasReservation(_ leaseID: WaylandGraphicsFrameLeaseID) -> Bool {
        entries.values.contains { entry in
            guard case .reserved(let activeLeaseID) = entry.lifecycle else {
                return false
            }

            return activeLeaseID == leaseID
        }
    }

    mutating func reserve(
        bufferID: WaylandGraphicsExternalBufferID,
        leaseID: WaylandGraphicsFrameLeaseID
    ) -> Bool {
        guard !leaseHasReservation(leaseID),
            case .available = entries[bufferID]?.lifecycle
        else {
            return false
        }

        entries[bufferID]?.lifecycle = .reserved(leaseID)
        return true
    }

    mutating func releaseReservation(
        bufferID: WaylandGraphicsExternalBufferID,
        leaseID: WaylandGraphicsFrameLeaseID
    ) {
        guard case .reserved(let activeLeaseID) = entries[bufferID]?.lifecycle,
            activeLeaseID == leaseID
        else {
            return
        }

        entries[bufferID]?.lifecycle = .available
    }

    mutating func releaseReservations(leaseID: WaylandGraphicsFrameLeaseID) {
        for bufferID in Array(entries.keys) {
            releaseReservation(bufferID: bufferID, leaseID: leaseID)
        }
    }

    mutating func nextReleasePoint(
        for bufferID: WaylandGraphicsExternalBufferID
    ) -> UInt64? {
        guard let releasePoint = entries[bufferID]?.nextExplicitReleasePoint else {
            return nil
        }

        entries[bufferID]?.nextExplicitReleasePoint = releasePoint + 1
        return releasePoint
    }

    mutating func markSubmitted(
        bufferID: WaylandGraphicsExternalBufferID,
        leaseID: WaylandGraphicsFrameLeaseID,
        submissionID: WaylandGraphicsExternalSubmissionID
    ) -> Bool {
        guard case .reserved(let activeLeaseID) = entries[bufferID]?.lifecycle,
            activeLeaseID == leaseID
        else {
            return false
        }

        entries[bufferID]?.lifecycle = .inCompositorUse(submissionID)
        return true
    }

    mutating func markReleased(
        bufferID: WaylandGraphicsExternalBufferID
    ) -> Entry? {
        switch entries[bufferID]?.lifecycle {
        case .inCompositorUse:
            entries[bufferID]?.lifecycle = .available
            return nil
        case .retiring(_, .some):
            return entries.removeValue(forKey: bufferID)
        case .available, .reserved, .retiring, nil:
            return nil
        }
    }

    mutating func markRetiring(
        bufferID: WaylandGraphicsExternalBufferID,
        reason: RetirementReason
    ) -> Entry? {
        switch entries[bufferID]?.lifecycle {
        case .available, .reserved:
            return entries.removeValue(forKey: bufferID)
        case .inCompositorUse(let submissionID):
            entries[bufferID]?.lifecycle = .retiring(reason, submissionID)
            return nil
        case .retiring, nil:
            return nil
        }
    }

    func lifecycle(
        for bufferID: WaylandGraphicsExternalBufferID
    ) -> Lifecycle? {
        entries[bufferID]?.lifecycle
    }
}

// SAFETY: All mutable registry dictionaries are protected by lock; public
// receipt continuations are completed through the registry without exposing
// unsynchronized state.
@safe
private final class WaylandGraphicsExternalReleaseRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var statesBySubmissionID:
        [WaylandGraphicsExternalSubmissionID: WaylandGraphicsExternalReleaseState] = [:]
    private var submissionIDsBySlotID: [GBMBufferPoolSlotID: WaylandGraphicsExternalSubmissionID] =
        [:]
    private var monitorTasksBySubmissionID:
        [WaylandGraphicsExternalSubmissionID: Task<Void, Never>] = [:]

    func begin(
        submissionID: WaylandGraphicsExternalSubmissionID,
        slotID: GBMBufferPoolSlotID
    ) -> WaylandGraphicsExternalReleaseState {
        let state = WaylandGraphicsExternalReleaseState()
        lock.lock()
        statesBySubmissionID[submissionID] = state
        submissionIDsBySlotID[slotID] = submissionID
        lock.unlock()
        return state
    }

    func finish(
        slotID: GBMBufferPoolSlotID,
        result: WaylandGraphicsExternalReleaseResult
    ) {
        let state: WaylandGraphicsExternalReleaseState?
        let monitorTask: Task<Void, Never>?
        lock.lock()
        if let submissionID = submissionIDsBySlotID.removeValue(forKey: slotID) {
            state = statesBySubmissionID.removeValue(forKey: submissionID)
            monitorTask = monitorTasksBySubmissionID.removeValue(forKey: submissionID)
        } else {
            state = nil
            monitorTask = nil
        }
        lock.unlock()

        monitorTask?.cancel()
        guard let state else { return }
        // swiftlint:disable:next no_unstructured_task
        Task {
            await state.finish(result)
        }
    }

    func finish(
        submissionID: WaylandGraphicsExternalSubmissionID,
        result: WaylandGraphicsExternalReleaseResult
    ) {
        let state: WaylandGraphicsExternalReleaseState?
        let monitorTask: Task<Void, Never>?
        lock.lock()
        state = statesBySubmissionID.removeValue(forKey: submissionID)
        monitorTask = monitorTasksBySubmissionID.removeValue(forKey: submissionID)
        submissionIDsBySlotID = submissionIDsBySlotID.filter { $0.value != submissionID }
        lock.unlock()

        monitorTask?.cancel()
        guard let state else { return }
        // swiftlint:disable:next no_unstructured_task
        Task {
            await state.finish(result)
        }
    }

    func trackMonitorTask(
        _ task: Task<Void, Never>,
        submissionID: WaylandGraphicsExternalSubmissionID
    ) {
        var shouldCancel = false
        lock.lock()
        if statesBySubmissionID[submissionID] == nil {
            shouldCancel = true
        } else {
            monitorTasksBySubmissionID[submissionID] = task
        }
        lock.unlock()

        if shouldCancel {
            task.cancel()
        }
    }

    func finishAll(result: WaylandGraphicsExternalReleaseResult) {
        let states: [WaylandGraphicsExternalReleaseState]
        let monitorTasks: [Task<Void, Never>]
        lock.lock()
        states = Array(statesBySubmissionID.values)
        monitorTasks = Array(monitorTasksBySubmissionID.values)
        statesBySubmissionID.removeAll()
        submissionIDsBySlotID.removeAll()
        monitorTasksBySubmissionID.removeAll()
        lock.unlock()

        for task in monitorTasks {
            task.cancel()
        }
        for state in states {
            // swiftlint:disable:next no_unstructured_task
            Task {
                await state.finish(result)
            }
        }
    }
}

// SAFETY: The release-retirement handler is protected by lock and invoked
// outside the critical section so callback work cannot re-enter locked state.
// swiftlint:disable:next type_name
private final class WaylandGraphicsExternalReleaseRetirementNotifier: @unchecked Sendable {
    private let lock = NSLock()
    private var onRelease: (@Sendable () -> Void)?

    func setHandler(_ handler: @escaping @Sendable () -> Void) {
        lock.lock()
        onRelease = handler
        lock.unlock()
    }

    func notify() {
        lock.lock()
        let handler = onRelease
        lock.unlock()
        handler?()
    }
}

// swiftlint:disable:next type_body_length
package actor WaylandGraphicsWindowBackingStorage {
    let window: any WaylandGraphicsManagedWindow
    private let configuration: WaylandGraphicsConfiguration
    private let managedGPUBacking: (any WaylandGraphicsManagedGPUBacking)?
    private let externalReleaseRegistry: WaylandGraphicsExternalReleaseRegistry
    private let externalReleaseRetirementNotifier: WaylandGraphicsExternalReleaseRetirementNotifier
    private let externalBufferPresenter: GPUWindowPresenter
    private var backingRuntimePath: WaylandGraphicsRuntimePath
    private var leaseState = WaylandGraphicsFrameLeaseState()
    private var nextExternalBufferSlotRawValue = 0
    private var nextExternalBufferIDRawValue: UInt64 = 1
    private var nextExternalSubmissionRawValue: UInt64 = 1
    private var nextExternalSyncTimelineRawValue: UInt64 = 1
    private var currentSurfaceGeneration = WaylandGraphicsSurfaceGeneration(rawValue: 1)
    private var lastContractGeometry: SurfaceGeometry?
    // swiftlint:disable:next discouraged_optional_collection
    private var lastContractConfigurationFacts: [ExternalBufferConfigurationFact]?
    private var lastContractSynchronization: WaylandGraphicsExternalSynchronizationAvailability?
    private var externalBufferRegistry = ExternalBufferRegistryState()
    private var importedExternalSyncTimelineIDs: Set<WaylandGraphicsExternalSyncTimelineID> = []

    package init(
        window backingWindow: any WaylandGraphicsManagedWindow,
        runtimePath initialRuntimePath: WaylandGraphicsRuntimePath,
        configuration backingConfiguration: WaylandGraphicsConfiguration = .default,
        managedGPUBacking gpuBacking: (any WaylandGraphicsManagedGPUBacking)? = nil
    ) {
        window = backingWindow
        configuration = backingConfiguration
        managedGPUBacking = gpuBacking
        let releaseRegistry = WaylandGraphicsExternalReleaseRegistry()
        let releaseRetirementNotifier = WaylandGraphicsExternalReleaseRetirementNotifier()
        externalReleaseRegistry = releaseRegistry
        externalReleaseRetirementNotifier = releaseRetirementNotifier
        let releaseRegistryForPresenter = releaseRegistry
        let releaseNotifierForPresenter = releaseRetirementNotifier
        let onImplicitRelease: @Sendable (GBMBufferPoolSlotID) -> Void = { slotID in
            releaseRegistryForPresenter.finish(
                slotID: slotID,
                result: .released
            )
            releaseNotifierForPresenter.notify()
        }
        externalBufferPresenter = GPUWindowPresenter(onImplicitRelease: onImplicitRelease)
        backingRuntimePath = initialRuntimePath
        releaseRetirementNotifier.setHandler { [weak self] in
            // swiftlint:disable:next no_unstructured_task
            Task {
                await self?.retireStaleAvailableExternalBuffers()
            }
        }
    }

    func runtimePath() throws -> WaylandGraphicsRuntimePath {
        try leaseState.requireNotClosed()
        return backingRuntimePath
    }

    package func nextFrame() async throws -> WaylandGraphicsFrameLease {
        try await nextFrame(afterWindowCheck: noGraphicsPreviewSubmissionHook)
    }

    func nextFrame(
        afterWindowCheck: @Sendable () async -> Void
    ) async throws -> WaylandGraphicsFrameLease {
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()
        await afterWindowCheck()
        try leaseState.requireNotClosed()

        let geometry: SurfaceGeometry
        do {
            geometry = try await frameLeaseGeometry()
            try leaseState.requireNotClosed()
        } catch {
            throw graphicsError(for: error, stage: .frameGeometry)
        }
        let leaseID = try leaseState.issueLease()
        let contract = await frameContract(for: geometry)
        return WaylandGraphicsFrameLease(
            id: leaseID,
            size: geometry.bufferSize,
            contract: contract,
            runtimePath: backingRuntimePath,
            storage: self
        )
    }

    func submit(
        leaseID: WaylandGraphicsFrameLeaseID,
        frame: WaylandGraphicsSubmittedFrame
    ) async throws -> WaylandGraphicsFrameResult {
        try await submit(
            leaseID: leaseID,
            frame: frame,
            schedule: nil,
            beforeSubmissionEffect: noThrowingGraphicsPreviewSubmissionHook,
            afterSubmissionEffect: noGraphicsPreviewSubmissionHook
        )
    }

    private func frameContract(
        for geometry: SurfaceGeometry
    ) async -> WaylandGraphicsFrameContract {
        let configurationFacts = externalBufferConfigurationFacts()
        let synchronization = externalSynchronizationAvailability()
        var generationChanged = false
        if let lastContractGeometry,
            lastContractGeometry != geometry
                || lastContractConfigurationFacts != configurationFacts
                || lastContractSynchronization != synchronization
        {
            currentSurfaceGeneration = WaylandGraphicsSurfaceGeneration(
                rawValue: currentSurfaceGeneration.rawValue + 1
            )
            generationChanged = true
        }
        lastContractGeometry = geometry
        lastContractConfigurationFacts = configurationFacts
        lastContractSynchronization = synchronization
        if generationChanged {
            await retireStaleAvailableExternalBuffers()
        }

        let configurations = configurationFacts.enumerated().map { index, fact in
            WaylandGraphicsExternalBufferConfiguration(
                id: WaylandGraphicsExternalConfigurationID(
                    rawValue: UInt64(index + 1)
                ),
                format: fact.format,
                modifier: fact.modifier,
                renderNode: fact.renderNode,
                alphaMode: fact.alphaMode,
                scanoutPreferred: fact.scanoutPreferred,
                generation: currentSurfaceGeneration
            )
        }
        return WaylandGraphicsFrameContract(
            generation: currentSurfaceGeneration,
            windowID: window.id,
            geometry: geometry,
            externalBufferConfigurations: configurations,
            recommendedExternalConfigurationID: configurations.first?.id,
            synchronization: synchronization,
            runtimePath: backingRuntimePath
        )
    }

    private func externalBufferConfigurationFacts()
        -> [ExternalBufferConfigurationFact]
    {
        guard let feedback = backingRuntimePath.capabilities.dmabufFeedback else {
            return []
        }

        var facts: [ExternalBufferConfigurationFact] = []
        for tranche in feedback.snapshot.tranches {
            for formatModifier in tranche.formats
            where
                (formatModifier.format == WaylandGraphicsDRMFormat.xrgb8888.rawValue
                || formatModifier.format
                    == WaylandGraphicsDRMFormat.argb8888.rawValue)
            {
                let format: WaylandGraphicsDRMFormat =
                    formatModifier.format == WaylandGraphicsDRMFormat.argb8888.rawValue
                    ? .argb8888
                    : .xrgb8888
                let renderNodePath: String?
                do {
                    renderNodePath = try DRMRenderNodeSelector.renderNodePath(
                        for: tranche.targetDevice
                    )
                } catch {
                    _ = error
                    renderNodePath = nil
                }
                let fact = ExternalBufferConfigurationFact(
                    format: format,
                    modifier: WaylandGraphicsDRMFormatModifier(
                        rawValue: formatModifier.modifier
                    ),
                    renderNode: WaylandGraphicsRenderNode(
                        path: renderNodePath,
                        targetDevice: tranche.targetDevice
                    ),
                    alphaMode: format == .argb8888 ? .premultiplied : .opaque,
                    scanoutPreferred: tranche.flags.contains(.scanout)
                )
                if !facts.contains(fact) {
                    facts.append(fact)
                }
            }
        }
        return facts
    }

    private func retireStaleAvailableExternalBuffers() async {
        let availableSlots = Set(externalBufferPresenter.availableSlotIDs)
        var retiredEntries: [ExternalBufferRegistryState.Entry] = []
        for (bufferID, registration) in externalBufferRegistry.entries {
            let buffer = registration.handle
            guard buffer.generation != currentSurfaceGeneration else {
                continue
            }

            do {
                let slotID = try externalBufferSlotID(for: buffer)
                guard availableSlots.contains(slotID) else {
                    _ = externalBufferRegistry.markRetiring(
                        bufferID: bufferID,
                        reason: .staleContract
                    )
                    continue
                }

                try externalBufferPresenter.retireAvailableBuffer(slotID)
                if let retiredEntry = externalBufferRegistry.markReleased(
                    bufferID: bufferID
                ) {
                    retiredEntries.append(retiredEntry)
                }
                if let retiredEntry = externalBufferRegistry.markRetiring(
                    bufferID: bufferID,
                    reason: .staleContract
                ) {
                    retiredEntries.append(retiredEntry)
                }
            } catch {
                _ = error
            }
        }

        for entry in retiredEntries {
            await removeExternalReleaseTimelineIfNeeded(entry)
        }
    }

    private func externalSynchronizationAvailability()
        -> WaylandGraphicsExternalSynchronizationAvailability
    {
        guard backingRuntimePath.capabilities.explicitSync.isAvailable else {
            return configuration.synchronizationPolicy == .requireExplicit
                ? .explicitRequiredUnavailable
                : .implicitOnly
        }

        return configuration.synchronizationPolicy == .implicitOnly
            ? .implicitOnly
            : .explicitAvailable
    }

    // swiftlint:disable:next function_body_length
    package func registerExternalBuffer(
        _ externalDescriptor: consuming WaylandGraphicsExternalBufferDescriptor,
        contract frameContract: WaylandGraphicsFrameContract,
        configurationID externalConfigurationID: WaylandGraphicsExternalConfigurationID
    ) async throws -> WaylandGraphicsExternalBuffer {
        var descriptor = externalDescriptor
        let selectedConfiguration: WaylandGraphicsExternalBufferConfiguration
        do {
            try leaseState.requireNotClosed()
            try await ensureWindowOpen()
            selectedConfiguration = try validateExternalBufferRegistration(
                descriptor,
                contract: frameContract,
                configurationID: externalConfigurationID
            )
        } catch {
            closeExternalDescriptor(&descriptor)
            throw graphicsError(for: externalGraphicsError(error), stage: .frameGeometry)
        }

        let bufferSize = descriptor.size
        let bufferFormat = descriptor.format
        let bufferModifier = descriptor.modifier
        let importedBuffer: RawLinuxDmabufBuffer
        do {
            importedBuffer = try await window.importGraphicsPreviewExternalBuffer(
                descriptor
            )
        } catch {
            throw graphicsError(for: externalGraphicsError(error), stage: .frameGeometry)
        }

        let explicitReleaseTimeline: WaylandGraphicsExternalReleaseTimeline?
        do {
            explicitReleaseTimeline = try await prepareExternalReleaseTimelineIfNeeded(
                selectedConfiguration: selectedConfiguration
            )
        } catch {
            importedBuffer.destroy()
            throw graphicsError(for: externalGraphicsError(error), stage: .frameGeometry)
        }

        let slotID = try nextExternalBufferSlotID()
        do {
            try externalBufferPresenter.installBuffer(
                importedBuffer,
                slotID: slotID
            )
        } catch {
            importedBuffer.destroy()
            explicitReleaseTimeline?.destroy()
            throw graphicsError(for: externalGraphicsError(error), stage: .frameGeometry)
        }

        let bufferID = nextExternalBufferID()
        let handle = WaylandGraphicsExternalBuffer(
            id: bufferID,
            generation: frameContract.generation,
            configurationID: externalConfigurationID,
            size: bufferSize,
            format: bufferFormat,
            modifier: bufferModifier,
            renderNode: selectedConfiguration.renderNode,
            windowID: window.id,
            slotRawValue: slotID.rawValue,
            storage: self
        )
        externalBufferRegistry.insert(
            handle: handle,
            explicitReleaseTimeline: explicitReleaseTimeline
        )
        refreshRuntimePathFromExternalBuffer(backing: .configured)
        return handle
    }

    private func validateExternalBufferRegistration(
        _ descriptor: borrowing WaylandGraphicsExternalBufferDescriptor,
        contract frameContract: WaylandGraphicsFrameContract,
        configurationID externalConfigurationID: WaylandGraphicsExternalConfigurationID
    ) throws -> WaylandGraphicsExternalBufferConfiguration {
        guard configuration.presentationMode == .externalGPU,
            configuration.fallbackPolicy != .forceSoftware
        else {
            throw WaylandGraphicsError.unavailable(.managedGPUSubmissionUnavailable)
        }
        guard frameContract.windowID == window.id else {
            throw staleFrameContract(rendered: frameContract.generation)
        }
        guard frameContract.generation == currentSurfaceGeneration else {
            throw staleFrameContract(rendered: frameContract.generation)
        }
        guard frameContract.geometry.bufferSize == descriptor.size else {
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }
        guard backingRuntimePath.capabilities.dmabuf.isAvailable else {
            throw WaylandGraphicsError.unavailable(.dmabufUnavailable)
        }
        guard
            let configuration = frameContract.externalBufferConfigurations.first(
                where: { $0.id == externalConfigurationID }
            )
        else {
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }
        guard configuration.generation == frameContract.generation,
            configuration.format == descriptor.format,
            configuration.modifier == descriptor.modifier
        else {
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }
        try validateExternalSynchronizationAvailability(frameContract)
        return configuration
    }

    private func validateExternalSynchronizationAvailability(
        _ frameContract: WaylandGraphicsFrameContract
    ) throws {
        guard configuration.synchronizationPolicy == .requireExplicit else {
            return
        }
        guard frameContract.synchronization == .explicitAvailable else {
            throw WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable)
        }
    }

    private func removeExternalReleaseTimelineIfNeeded(
        _ entry: ExternalBufferRegistryState.Entry
    ) async {
        guard let timeline = entry.explicitReleaseTimeline else {
            return
        }

        do {
            try await window.removeGraphicsPreviewSynchronizationTimeline(
                identity: SurfaceSyncTimelineIdentity(timeline.identity.rawValue)
            )
        } catch {
            _ = error
        }
        timeline.destroy()
    }

    private func prepareExternalReleaseTimelineIfNeeded(
        selectedConfiguration: WaylandGraphicsExternalBufferConfiguration
    ) async throws -> WaylandGraphicsExternalReleaseTimeline? {
        guard configuration.synchronizationPolicy != .implicitOnly else {
            return nil
        }
        guard backingRuntimePath.capabilities.explicitSync.isAvailable else {
            if configuration.synchronizationPolicy == .requireExplicit {
                throw WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable)
            }
            return nil
        }

        do {
            let timelineID = nextExternalSyncTimelineID()
            let releaseTimeline = try WaylandGraphicsExternalReleaseTimeline(
                renderNode: selectedConfiguration.renderNode,
                identity: GPUSyncTimeline(timelineID.rawValue)
            )
            do {
                var timelineFileDescriptor = try releaseTimeline.exportFileDescriptor()
                try await window.importGraphicsPreviewSynchronizationTimeline(
                    &timelineFileDescriptor,
                    identity: SurfaceSyncTimelineIdentity(timelineID.rawValue)
                )
                return releaseTimeline
            } catch {
                releaseTimeline.destroy()
                throw error
            }
        } catch let error as WaylandGraphicsError {
            if configuration.synchronizationPolicy == .requireExplicit {
                throw error
            }
            return nil
        } catch {
            if configuration.synchronizationPolicy == .requireExplicit {
                throw WaylandGraphicsError.unavailable(.explicitSyncSetupFailed)
            }
            return nil
        }
    }

    package func importExternalSyncTimeline(
        _ fileDescriptor: consuming OwnedFileDescriptor
    ) async throws -> WaylandGraphicsExternalSyncTimeline {
        var descriptor = fileDescriptor
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()
        guard backingRuntimePath.capabilities.explicitSync.isAvailable else {
            do {
                try descriptor.close()
            } catch {
                _ = error
            }
            throw WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable)
        }

        let timelineID = nextExternalSyncTimelineID()
        let rawFileDescriptor = descriptor.releaseRawValue()
        do {
            var timelineFileDescriptor = try RawDrmSyncobjTimelineFD(
                adopting: rawFileDescriptor
            )
            do {
                try await window.importGraphicsPreviewSynchronizationTimeline(
                    &timelineFileDescriptor,
                    identity: SurfaceSyncTimelineIdentity(timelineID.rawValue)
                )
            } catch {
                timelineFileDescriptor.close()
                throw graphicsError(for: error, stage: .submissionPreparation)
            }
        } catch let error as RuntimeError {
            _ = error
            Glibc.close(rawFileDescriptor)
            throw graphicsError(
                for: WaylandGraphicsError.unavailable(.explicitSyncSetupFailed),
                stage: .submissionPreparation
            )
        } catch let error as WaylandGraphicsError {
            throw error
        } catch {
            throw graphicsError(for: error, stage: .submissionPreparation)
        }

        importedExternalSyncTimelineIDs.insert(timelineID)
        return WaylandGraphicsExternalSyncTimeline(
            id: timelineID,
            windowID: window.id
        )
    }

    package func reserveExternalBuffer(
        _ buffer: WaylandGraphicsExternalBuffer,
        leaseID: WaylandGraphicsFrameLeaseID,
        contract frameContract: WaylandGraphicsFrameContract
    ) throws -> WaylandGraphicsExternalBufferRenderLease {
        try leaseState.requireSubmittable(leaseID: leaseID)
        try requireLocalRegisteredExternalBuffer(buffer)
        guard frameContract.generation == currentSurfaceGeneration,
            buffer.generation == currentSurfaceGeneration
        else {
            throw staleFrameContract(rendered: buffer.generation)
        }
        let slotID = try externalBufferSlotID(for: buffer)
        synchronizeExternalBufferRelease(bufferID: buffer.id, slotID: slotID)
        guard externalBufferPresenter.availableSlotIDs.contains(slotID),
            externalBufferRegistry.reserve(bufferID: buffer.id, leaseID: leaseID)
        else {
            throw externalBufferUnavailable(buffer)
        }

        return WaylandGraphicsExternalBufferRenderLease(
            buffer: buffer,
            contract: frameContract,
            frameLeaseID: leaseID,
            storage: self
        )
    }

    package func unregisterExternalBuffer(
        _ buffer: WaylandGraphicsExternalBuffer
    ) async throws {
        try leaseState.requireNotClosed()
        try requireLocalRegisteredExternalBuffer(buffer)
        guard externalBufferRegistry.reservation(for: buffer.id) == nil else {
            throw externalBufferUnavailable(buffer)
        }

        let slotID = try externalBufferSlotID(for: buffer)
        synchronizeExternalBufferRelease(bufferID: buffer.id, slotID: slotID)
        do {
            try externalBufferPresenter.retireAvailableBuffer(slotID)
        } catch {
            throw externalBufferUnavailable(buffer)
        }

        if let entry = externalBufferRegistry.markRetiring(
            bufferID: buffer.id,
            reason: .explicitUnregister
        ) {
            await removeExternalReleaseTimelineIfNeeded(entry)
        }
    }

    private func requireLocalRegisteredExternalBuffer(
        _ buffer: WaylandGraphicsExternalBuffer
    ) throws {
        guard buffer.windowID == window.id else {
            throw WaylandGraphicsError.externalBufferUnavailable(
                id: buffer.id,
                state: .foreign
            )
        }
        guard
            externalBufferRegistry.entry(for: buffer.id)?.handle.slotRawValue
                == buffer.slotRawValue
        else {
            throw WaylandGraphicsError.externalBufferUnavailable(
                id: buffer.id,
                state: .unregistered
            )
        }
    }

    private func externalBufferSlotID(
        for buffer: WaylandGraphicsExternalBuffer
    ) throws -> GBMBufferPoolSlotID {
        do {
            return try GBMBufferPoolSlotID(buffer.slotRawValue)
        } catch {
            throw externalBufferUnavailable(buffer)
        }
    }

    private func staleFrameContract(
        rendered generation: WaylandGraphicsSurfaceGeneration
    ) -> WaylandGraphicsError {
        .staleFrameContract(rendered: generation, current: currentSurfaceGeneration)
    }

    private func externalBufferUnavailable(
        _ buffer: WaylandGraphicsExternalBuffer
    ) -> WaylandGraphicsError {
        .externalBufferUnavailable(id: buffer.id, state: externalBufferLifecycle(buffer))
    }

    private func externalBufferLifecycle(
        _ buffer: WaylandGraphicsExternalBuffer
    ) -> WaylandGraphicsExternalBufferLifecycle {
        guard
            let registration = externalBufferRegistry.entry(for: buffer.id),
            registration.handle.slotRawValue == buffer.slotRawValue
        else {
            return .unregistered
        }
        let slotID: GBMBufferPoolSlotID
        do {
            slotID = try GBMBufferPoolSlotID(buffer.slotRawValue)
        } catch {
            return .unregistered
        }
        switch registration.lifecycle {
        case .reserved:
            return .reserved
        case .available:
            return .available
        case .inCompositorUse:
            return externalBufferPresenter.availableSlotIDs.contains(slotID)
                ? .available
                : .submittedAwaitingRelease
        case .retiring:
            return .submittedAwaitingRelease
        }
    }

    private func synchronizeExternalBufferRelease(
        bufferID: WaylandGraphicsExternalBufferID,
        slotID: GBMBufferPoolSlotID
    ) {
        if externalBufferPresenter.availableSlotIDs.contains(slotID) {
            _ = externalBufferRegistry.markReleased(bufferID: bufferID)
        }
    }

    func submit(
        leaseID: WaylandGraphicsFrameLeaseID,
        frame: WaylandGraphicsSubmittedFrame,
        schedule frameSchedule: WaylandGraphicsFrameSchedule
    ) async throws -> WaylandGraphicsFrameResult {
        try await submit(
            leaseID: leaseID,
            frame: frame,
            schedule: frameSchedule,
            beforeSubmissionEffect: noThrowingGraphicsPreviewSubmissionHook,
            afterSubmissionEffect: noGraphicsPreviewSubmissionHook
        )
    }

    func submit(
        leaseID: WaylandGraphicsFrameLeaseID,
        frame: WaylandGraphicsSubmittedFrame,
        schedule frameSchedule: WaylandGraphicsFrameSchedule? = nil,
        beforeSubmissionEffect: @Sendable () async throws -> Void,
        afterSubmissionEffect: @Sendable () async throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        let effectiveConfiguration = configuration.applying(schedule: frameSchedule)
        let geometry: SurfaceGeometry
        try leaseState.requireNotClosed()
        do {
            try await ensureWindowOpen()
            try await prepareInitialConfigure(
                leaseID: leaseID,
                shouldPrepare: shouldAttemptManagedGPU
            )

            geometry = try await submissionGeometry(for: leaseID)
            try effectiveConfiguration.validateManagedPreviewSupport(
                capabilities: backingRuntimePath.capabilities
            )
            try frame.validateManagedPreviewSupport(
                configuration: effectiveConfiguration,
                capabilities: backingRuntimePath.capabilities,
                geometry: geometry
            )
        } catch {
            releaseExternalBufferReservationsAndCancelLease(leaseID: leaseID)
            throw error
        }
        let operation = try leaseState.prepareSubmission(leaseID: leaseID)
        var stage = WaylandGraphicsSubmissionStage.submissionPreparation
        do {
            try await beforeSubmissionEffect()
            stage = .frameSubmission
            try await submitFrame(
                frame,
                operation: operation,
                geometry: geometry,
                configuration: effectiveConfiguration
            )
            stage = .submissionCompletion
            try await afterSubmissionEffect()
            releaseExternalBufferReservations(leaseID: leaseID)
            try leaseState.finishSubmission()
            return frameResult(
                operation: operation,
                size: geometry.bufferSize,
                metadata: frame.metadata,
                configuration: effectiveConfiguration
            )
        } catch {
            releaseExternalBufferReservations(leaseID: leaseID)
            if Self.isCommittedManagedGPUFrameFailure(error) {
                finishCommittedSubmissionFailure()
            } else {
                leaseState.failSubmission()
            }
            throw graphicsError(for: error, stage: stage, operation: operation)
        }
    }

    func submitSoftware(
        leaseID: WaylandGraphicsFrameLeaseID,
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try await submitSoftware(
            leaseID: leaseID,
            metadata: frameMetadata,
            schedule: nil,
            draw
        )
    }

    func submitSoftware(
        leaseID: WaylandGraphicsFrameLeaseID,
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        schedule frameSchedule: WaylandGraphicsFrameSchedule?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        let effectiveConfiguration = configuration.applying(schedule: frameSchedule)
        let geometry: SurfaceGeometry
        try leaseState.requireNotClosed()
        do {
            try await ensureWindowOpen()
            try rejectSoftwareSubmissionWhenUnavailable(configuration: effectiveConfiguration)

            geometry = try await submissionGeometry(for: leaseID)
            try effectiveConfiguration.validateManagedPreviewSupport(
                capabilities: backingRuntimePath.capabilities
            )
            try frameMetadata.validateManagedPreviewSupport(
                configuration: effectiveConfiguration,
                capabilities: backingRuntimePath.capabilities,
                geometry: geometry
            )
        } catch {
            releaseExternalBufferReservationsAndCancelLease(leaseID: leaseID)
            throw error
        }
        let operation = try leaseState.prepareSubmission(leaseID: leaseID)
        var stage = WaylandGraphicsSubmissionStage.submissionPreparation
        do {
            stage = .frameSubmission
            try await submitSoftwareFrame(
                metadata: frameMetadata,
                operation: operation,
                geometry: geometry,
                configuration: effectiveConfiguration,
                draw
            )
            stage = .submissionCompletion
            releaseExternalBufferReservations(leaseID: leaseID)
            try leaseState.finishSubmission()
            return frameResult(
                operation: operation,
                size: geometry.bufferSize,
                metadata: frameMetadata,
                configuration: effectiveConfiguration
            )
        } catch {
            releaseExternalBufferReservations(leaseID: leaseID)
            leaseState.failSubmission()
            if let drawError = WaylandGraphicsErrorMapper.callerDrawError(from: error) {
                throw drawError
            }
            throw graphicsError(for: error, stage: stage, operation: operation)
        }
    }

    // swiftlint:disable:next function_body_length
    package func submitRegisteredExternalBuffer(
        leaseID: WaylandGraphicsFrameLeaseID,
        buffer externalBuffer: WaylandGraphicsExternalBuffer,
        acquireSynchronization: WaylandGraphicsExternalAcquireSynchronization?,
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        schedule frameSchedule: WaylandGraphicsFrameSchedule?
    ) async throws -> WaylandGraphicsExternalBufferSubmissionReceipt {
        let effectiveConfiguration = configuration.applying(schedule: frameSchedule)
        let geometry: SurfaceGeometry
        let operation: WaylandGraphicsFrameSubmissionOperation
        do {
            try leaseState.requireNotClosed()
            try await ensureWindowOpen()
            try requireLocalRegisteredExternalBuffer(externalBuffer)
            guard externalBufferRegistry.reservation(for: externalBuffer.id) == leaseID else {
                throw externalBufferUnavailable(externalBuffer)
            }
            geometry = try await submissionGeometry(for: leaseID)
            operation = try prepareRegisteredExternalBufferSubmission(
                externalBuffer,
                leaseID: leaseID,
                metadata: frameMetadata,
                geometry: geometry,
                configuration: effectiveConfiguration
            )
        } catch {
            releaseExternalBufferReservation(
                bufferID: externalBuffer.id,
                leaseID: leaseID
            )
            throw error
        }

        var stage = WaylandGraphicsSubmissionStage.submissionPreparation
        do {
            stage = .frameSubmission
            let submittedExternalFrame = try await submitRegisteredExternalBufferFrame(
                externalBuffer,
                acquireSynchronization: acquireSynchronization,
                metadata: frameMetadata,
                geometry: geometry,
                configuration: effectiveConfiguration
            )
            stage = .submissionCompletion
            try markExternalBufferSubmitted(
                externalBuffer,
                leaseID: leaseID,
                submissionID: submittedExternalFrame.submissionID
            )
            try leaseState.finishSubmission()
            let result = frameResult(
                operation: operation,
                size: geometry.bufferSize,
                metadata: frameMetadata,
                configuration: effectiveConfiguration
            )
            return WaylandGraphicsExternalBufferSubmissionReceipt(
                id: submittedExternalFrame.submissionID,
                bufferID: externalBuffer.id,
                contractGeneration: externalBuffer.generation,
                frameResult: result,
                releaseMechanism: submittedExternalFrame.releaseMechanism,
                releaseState: submittedExternalFrame.releaseState
            )
        } catch {
            releaseExternalBufferReservation(
                bufferID: externalBuffer.id,
                leaseID: leaseID
            )
            if Self.isCommittedExternalBufferFrameFailure(error) {
                finishCommittedSubmissionFailure()
            } else {
                leaseState.failSubmission()
            }
            throw graphicsError(
                for: externalGraphicsError(error), stage: stage, operation: operation)
        }
    }

    package func cancelExternalBufferReservation(
        _ buffer: WaylandGraphicsExternalBuffer,
        leaseID: WaylandGraphicsFrameLeaseID
    ) {
        releaseExternalBufferReservation(bufferID: buffer.id, leaseID: leaseID)
    }

    private func releaseExternalBufferReservation(
        bufferID: WaylandGraphicsExternalBufferID,
        leaseID: WaylandGraphicsFrameLeaseID
    ) {
        externalBufferRegistry.releaseReservation(
            bufferID: bufferID,
            leaseID: leaseID
        )
    }

    private func releaseExternalBufferReservations(
        leaseID: WaylandGraphicsFrameLeaseID
    ) {
        externalBufferRegistry.releaseReservations(leaseID: leaseID)
    }

    private func releaseExternalBufferReservationsAndCancelLease(
        leaseID: WaylandGraphicsFrameLeaseID
    ) {
        releaseExternalBufferReservations(leaseID: leaseID)
        _ = leaseState.cancel(leaseID: leaseID)
    }

    private func markExternalBufferSubmitted(
        _ externalBuffer: WaylandGraphicsExternalBuffer,
        leaseID: WaylandGraphicsFrameLeaseID,
        submissionID: WaylandGraphicsExternalSubmissionID
    ) throws {
        guard
            externalBufferRegistry.markSubmitted(
                bufferID: externalBuffer.id,
                leaseID: leaseID,
                submissionID: submissionID
            )
        else {
            throw externalBufferUnavailable(externalBuffer)
        }
    }

    private func closeExternalDescriptor(
        _ descriptor: inout WaylandGraphicsExternalBufferDescriptor
    ) {
        do {
            try descriptor.closeFileDescriptors()
        } catch {
            _ = error
        }
    }

    private func submitRegisteredExternalBufferFrame(
        _ externalBuffer: WaylandGraphicsExternalBuffer,
        acquireSynchronization: WaylandGraphicsExternalAcquireSynchronization?,
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) async throws -> (
        submissionID: WaylandGraphicsExternalSubmissionID,
        releaseMechanism: WaylandGraphicsExternalReleaseMechanism,
        releaseState: WaylandGraphicsExternalReleaseState
    ) {
        let resolvedMetadata = try frameMetadata.resolveManagedPreviewMetadata(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let pacingSelection = try Self.softwarePacingSelection(
            policy: effectiveConfiguration.gpuPacingPolicy,
            capabilities: backingRuntimePath.capabilities,
            fifoBarrierPrimed: leaseState.hasSubmittedFrame
        )
        let synchronization = try externalSubmissionSynchronization(
            for: externalBuffer,
            acquireSynchronization: acquireSynchronization,
            configuration: effectiveConfiguration
        )
        let submittedExternalFrame = try await presentRegisteredExternalBuffer(
            externalBuffer,
            synchronization: synchronization,
            pacing: pacingSelection.constraint,
            metadata: resolvedMetadata.commitMetadata,
            requestPresentationFeedback: shouldRequestPresentationFeedback(
                configuration: effectiveConfiguration
            )
        )
        refreshRuntimePathFromExternalBuffer(backing: .active)
        applyPacingSelection(pacingSelection)
        applyMetadataFallbacks(resolvedMetadata.fallbacks)
        applyExternalSynchronizationStatus(
            configuration: effectiveConfiguration,
            synchronization: synchronization.presentation
        )
        return submittedExternalFrame
    }

    private func submissionGeometry(
        for leaseID: WaylandGraphicsFrameLeaseID
    ) async throws -> SurfaceGeometry {
        do {
            let operation = try leaseState.submissionOperation(leaseID: leaseID)
            let geometry = try await submissionGeometry(for: operation)
            try leaseState.requireSubmittable(leaseID: leaseID)
            return geometry
        } catch {
            throw graphicsError(for: error, stage: .frameGeometry)
        }
    }

    private func frameLeaseGeometry() async throws -> SurfaceGeometry {
        if shouldAttemptExternalBufferPresentation {
            let geometry = try await window.prepareGraphicsPreviewPresentation(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds
            )
            do {
                let capabilities = try await window.requestGraphicsPreviewSurfaceFeedback(
                    timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds
                )
                backingRuntimePath = Self.runtimePath(
                    backingRuntimePath,
                    capabilities: WaylandGraphicsSurfaceCapabilities(
                        snapshot: GraphicsPreviewSurfaceCapabilitySnapshot(
                            snapshot: capabilities
                        )
                    ),
                    surfaceFeedback: .active
                )
            } catch let error as GraphicsPreviewSurfaceFeedbackError {
                try handleExternalSurfaceFeedbackFailure(error)
            }
            return geometry
        }

        guard shouldAttemptManagedGPU, leaseState.hasSubmittedFrame else {
            return try await window.geometry
        }

        return try await window.prepareGraphicsPreviewPresentation(timeoutMilliseconds: 0)
    }

    private func submissionGeometry(
        for operation: WaylandGraphicsFrameSubmissionOperation
    ) async throws -> SurfaceGeometry {
        guard shouldAttemptManagedGPU, operation == .redraw else {
            return try await window.geometry
        }

        return try await window.prepareGraphicsPreviewPresentation(timeoutMilliseconds: 0)
    }

    private func prepareInitialConfigure(
        leaseID: WaylandGraphicsFrameLeaseID,
        shouldPrepare: Bool
    ) async throws {
        guard shouldPrepare else { return }
        if shouldAttemptExternalBufferPresentation,
            lastContractGeometry != nil
        {
            return
        }

        let operation = try leaseState.submissionOperation(leaseID: leaseID)
        guard operation == .show else { return }

        do {
            _ = try await window.prepareGraphicsPreviewPresentation(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds
            )
            try leaseState.requireSubmittable(leaseID: leaseID)
        } catch {
            throw graphicsError(for: error, stage: .frameGeometry)
        }
    }

    private func ensureWindowOpen() async throws {
        do {
            let windowIsClosed = try await window.isClosed
            try leaseState.requireNotClosed()
            guard !windowIsClosed else {
                throw WaylandGraphicsError.windowClosed
            }
        } catch {
            throw graphicsError(for: error, stage: .windowStateCheck)
        }
    }

    private func graphicsError(
        for error: any Error,
        stage: WaylandGraphicsSubmissionStage,
        operation: WaylandGraphicsFrameSubmissionOperation? = nil
    ) -> WaylandGraphicsError {
        if leaseState.isClosed {
            return .backingClosed
        }
        if let committedFailure = error as? CommittedManagedGPUFrameFailure {
            return .unavailable(WaylandGraphicsUnavailableReason(committedFailure.failure))
        }
        if let graphicsError = error as? WaylandGraphicsError {
            return graphicsError
        }
        return WaylandGraphicsErrorMapper.mapSubmissionError(
            error,
            windowID: window.id,
            operation: operation?.graphicsSubmissionOperation,
            stage: stage
        )
    }

    func cancel(leaseID: WaylandGraphicsFrameLeaseID) {
        if leaseState.cancel(leaseID: leaseID) {
            releaseExternalBufferReservations(leaseID: leaseID)
        }
    }

    func close() async throws {
        await close(shouldCloseWindow: true)
    }

    package func closeBecauseWindowClosed() async {
        await close(shouldCloseWindow: false)
    }

    private func close(shouldCloseWindow: Bool) async {
        guard !leaseState.isClosed else {
            return
        }

        leaseState.close()
        externalReleaseRegistry.finishAll(result: .retired(.backingClosed))
        externalBufferRegistry.removeAll()
        managedGPUBacking?.close()
        externalBufferPresenter.retireAll(reason: .windowClosed)
        if shouldCloseWindow {
            await window.close()
        }
    }

    private func submitFrame(
        _ frame: WaylandGraphicsSubmittedFrame,
        operation: WaylandGraphicsFrameSubmissionOperation,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) async throws {
        switch frame {
        case .clearColor(let clearFrame):
            try await submitClearFrame(
                clearFrame,
                operation: operation,
                geometry: geometry,
                configuration: effectiveConfiguration
            )
        }
    }

    private func submitClearFrame(
        _ frame: WaylandGraphicsClearFrame,
        operation: WaylandGraphicsFrameSubmissionOperation,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) async throws {
        let color = frame.color.xrgb8888
        let resolvedMetadata = try frame.metadata.resolveManagedPreviewMetadata(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let metadata = resolvedMetadata.commitMetadata
        let damage = try frame.metadata.surfaceDamageRegion()
        if shouldAttemptManagedGPU {
            do {
                _ = try await managedGPUBacking?.submitClearFrame(
                    WaylandGraphicsManagedGPUClearFrameSubmission(
                        color: frame.color.gpuClearColor,
                        metadata: metadata,
                        geometry: geometry,
                        synchronizationPolicy: effectiveConfiguration
                            .gpuSynchronizationPolicy,
                        pacingPolicy: effectiveConfiguration.gpuPacingPolicy,
                        requestPresentationFeedback: shouldRequestPresentationFeedback(
                            configuration: effectiveConfiguration
                        )
                    )
                )
                refreshRuntimePathFromManagedGPU(backing: .active)
                applyMetadataFallbacks(resolvedMetadata.fallbacks)
                return
            } catch {
                try handleManagedGPUFailure(error, configuration: effectiveConfiguration)
            }
        }

        try rejectSoftwareSubmissionWhenUnavailable(configuration: effectiveConfiguration)
        let pacingSelection = try Self.softwarePacingSelection(
            policy: effectiveConfiguration.gpuPacingPolicy,
            capabilities: backingRuntimePath.capabilities,
            fifoBarrierPrimed: leaseState.hasSubmittedFrame
        )
        let submitConstraints = SurfaceSubmitConstraints(
            synchronization: .implicit,
            pacing: pacingSelection.constraint
        )
        try await submitSoftwareClearFrame(
            color: color,
            operation: operation,
            submitConstraints: submitConstraints,
            metadata: metadata,
            damage: damage,
            configuration: effectiveConfiguration
        )
        applyPacingSelection(pacingSelection)
        applyMetadataFallbacks(resolvedMetadata.fallbacks)
    }

    // swiftlint:disable:next function_parameter_count
    private func submitSoftwareClearFrame(
        color: UInt32,
        operation: WaylandGraphicsFrameSubmissionOperation,
        submitConstraints: SurfaceSubmitConstraints,
        metadata: SurfaceCommitMetadata,
        damage: SurfaceDamageRegion?,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) async throws {
        switch operation {
        case .show:
            try await window.show(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds,
                submitConstraints: submitConstraints,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback(
                    configuration: effectiveConfiguration
                ),
                damage: damage
            ) { softwareFrame in
                clearSoftwareFrame(softwareFrame, color: color)
            }
        case .redraw:
            try await window.redraw(
                submitConstraints: submitConstraints,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback(
                    configuration: effectiveConfiguration
                ),
                damage: damage
            ) { softwareFrame in
                clearSoftwareFrame(softwareFrame, color: color)
            }
        }
    }

    private func submitSoftwareFrame(
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        operation: WaylandGraphicsFrameSubmissionOperation,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        let resolvedMetadata = try frameMetadata.resolveManagedPreviewMetadata(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let metadata = resolvedMetadata.commitMetadata
        let damage = try frameMetadata.surfaceDamageRegion()
        let pacingSelection = try Self.softwarePacingSelection(
            policy: effectiveConfiguration.gpuPacingPolicy,
            capabilities: backingRuntimePath.capabilities,
            fifoBarrierPrimed: leaseState.hasSubmittedFrame
        )
        let submitConstraints = SurfaceSubmitConstraints(
            synchronization: .implicit,
            pacing: pacingSelection.constraint
        )
        switch operation {
        case .show:
            try await window.show(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds,
                submitConstraints: submitConstraints,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback(
                    configuration: effectiveConfiguration
                ),
                damage: damage,
                draw
            )
        case .redraw:
            try await window.redraw(
                submitConstraints: submitConstraints,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback(
                    configuration: effectiveConfiguration
                ),
                damage: damage,
                draw
            )
        }
        applyPacingSelection(pacingSelection)
        applyMetadataFallbacks(resolvedMetadata.fallbacks)
    }
}

extension WaylandGraphicsWindowBackingStorage {
    private func shouldRequestPresentationFeedback(
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) -> Bool {
        Self.shouldRequestPresentationFeedback(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities
        )
    }

    private var shouldAttemptManagedGPU: Bool {
        guard managedGPUBacking != nil else {
            return false
        }
        guard configuration.presentationMode == .managedGPU,
            configuration.fallbackPolicy != .forceSoftware
        else {
            return false
        }
        guard case .fallback = backingRuntimePath.backing else {
            return true
        }

        return false
    }

    private var shouldAttemptExternalBufferPresentation: Bool {
        configuration.presentationMode == .externalGPU
            && configuration.fallbackPolicy != .forceSoftware
    }

    private func handleManagedGPUFailure(
        _ error: ManagedGPUPreviewBackingError,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) throws {
        if error.committedFrameWasPresented {
            let reason = WaylandGraphicsUnavailableReason(error.failure)
            updateBackingRuntimeStatus(.failed(reason))
            throw CommittedManagedGPUFrameFailure(error)
        }

        guard effectiveConfiguration.synchronizationPolicy != .requireExplicit else {
            let reason = WaylandGraphicsUnavailableReason(error.failure)
            updateBackingRuntimeStatus(.failed(reason))
            throw WaylandGraphicsError.unavailable(reason)
        }

        switch configuration.fallbackPolicy {
        case .preferGPUFallbackToSoftware:
            let reason = WaylandGraphicsFallbackReason(error.fallbackReason)
            updateBackingRuntimeStatus(.fallback(reason))
            backingRuntimePath = Self.runtimePath(
                backingRuntimePath,
                fallbackExplicitSyncIfNeeded: reason
            )
        case .requireGPU:
            let reason = WaylandGraphicsUnavailableReason(error.failure)
            updateBackingRuntimeStatus(.failed(reason))
            throw WaylandGraphicsError.unavailable(reason)
        case .forceSoftware:
            updateBackingRuntimeStatus(.fallback(.forcedSoftware))
        }
    }

    private func updateBackingRuntimeStatus(_ status: WaylandGraphicsRuntimeStatus) {
        guard !refreshRuntimePathFromManagedGPU(backing: status) else { return }
        backingRuntimePath = Self.runtimePath(backingRuntimePath, backing: status)
    }

    private func prepareRegisteredExternalBufferSubmission(
        _ externalBuffer: WaylandGraphicsExternalBuffer,
        leaseID: WaylandGraphicsFrameLeaseID,
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) throws -> WaylandGraphicsFrameSubmissionOperation {
        try effectiveConfiguration.validateManagedPreviewSupport(
            capabilities: backingRuntimePath.capabilities
        )
        try validateRegisteredExternalBuffer(
            externalBuffer,
            geometry: geometry,
            configuration: effectiveConfiguration
        )
        try frameMetadata.validateManagedPreviewSupport(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        return try leaseState.prepareSubmission(leaseID: leaseID)
    }

    private func validateRegisteredExternalBuffer(
        _ externalBuffer: WaylandGraphicsExternalBuffer,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) throws {
        guard backingRuntimePath.capabilities.dmabuf.isAvailable else {
            throw WaylandGraphicsError.unavailable(.dmabufUnavailable)
        }
        guard effectiveConfiguration.presentationMode == .externalGPU,
            effectiveConfiguration.fallbackPolicy != .forceSoftware
        else {
            throw WaylandGraphicsError.unavailable(.managedGPUSubmissionUnavailable)
        }
        guard externalBuffer.generation == currentSurfaceGeneration else {
            throw staleFrameContract(rendered: externalBuffer.generation)
        }
        guard externalBuffer.size == geometry.bufferSize else {
            throw staleFrameContract(rendered: externalBuffer.generation)
        }
    }

    private func presentRegisteredExternalBuffer(
        _ externalBuffer: WaylandGraphicsExternalBuffer,
        synchronization externalSynchronization: (
            presentation: GPUBufferSubmissionSynchronization,
            explicitReleaseTimeline: WaylandGraphicsExternalReleaseTimeline?
        ),
        pacing: SurfacePacingConstraint,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool
    ) async throws -> (
        submissionID: WaylandGraphicsExternalSubmissionID,
        releaseMechanism: WaylandGraphicsExternalReleaseMechanism,
        releaseState: WaylandGraphicsExternalReleaseState
    ) {
        let submissionID = nextExternalSubmissionID()
        let slotID = try externalBufferSlotID(for: externalBuffer)
        let releaseState = externalReleaseRegistry.begin(
            submissionID: submissionID,
            slotID: slotID
        )
        do {
            _ = try await externalBufferPresenter.presentSlot(
                slotID,
                submit: { [window] surfaceBuffer, submitConstraints, commitMetadata in
                    try await window.presentGraphicsPreviewBuffer(
                        surfaceBuffer,
                        submitConstraints: submitConstraints,
                        metadata: commitMetadata,
                        requestPresentationFeedback: requestPresentationFeedback
                    )
                },
                synchronization: externalSynchronization.presentation,
                pacing: pacing,
                metadata: metadata
            )
            if case .explicit(let syncState) = externalSynchronization.presentation,
                let explicitReleaseTimeline = externalSynchronization.explicitReleaseTimeline
            {
                monitorExternalExplicitRelease(
                    submissionID: submissionID,
                    slotID: slotID,
                    syncState: syncState,
                    releaseTimeline: explicitReleaseTimeline
                )
            }
            return (
                submissionID: submissionID,
                releaseMechanism: externalSynchronization.explicitReleaseTimeline == nil
                    ? .implicitWaylandBufferRelease
                    : .explicitSyncobjTimelinePoint,
                releaseState: releaseState
            )
        } catch {
            externalReleaseRegistry.finish(
                submissionID: submissionID,
                result: .failed(.commitFailed)
            )
            throw error
        }
    }

    private func externalSubmissionSynchronization(
        for externalBuffer: WaylandGraphicsExternalBuffer,
        acquireSynchronization: WaylandGraphicsExternalAcquireSynchronization?,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) throws -> (
        presentation: GPUBufferSubmissionSynchronization,
        explicitReleaseTimeline: WaylandGraphicsExternalReleaseTimeline?
    ) {
        switch effectiveConfiguration.synchronizationPolicy {
        case .implicitOnly:
            if acquireSynchronization != nil {
                throw WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable)
            }
            return (
                presentation: .implicit,
                explicitReleaseTimeline: nil
            )
        case .preferExplicit, .requireExplicit:
            guard
                let explicit = try explicitExternalSubmissionSynchronization(
                    for: externalBuffer,
                    acquireSynchronization: acquireSynchronization
                )
            else {
                if effectiveConfiguration.synchronizationPolicy == .requireExplicit
                    || acquireSynchronization != nil
                {
                    throw WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable)
                }
                return (
                    presentation: .implicit,
                    explicitReleaseTimeline: nil
                )
            }
            return explicit
        }
    }

    private func explicitExternalSubmissionSynchronization(
        for externalBuffer: WaylandGraphicsExternalBuffer,
        acquireSynchronization: WaylandGraphicsExternalAcquireSynchronization?
    ) throws -> (
        presentation: GPUBufferSubmissionSynchronization,
        explicitReleaseTimeline: WaylandGraphicsExternalReleaseTimeline?
    )? {
        guard backingRuntimePath.capabilities.explicitSync.isAvailable else {
            return nil
        }
        guard
            let registration = externalBufferRegistry.entry(for: externalBuffer.id),
            let releaseTimeline = registration.explicitReleaseTimeline
        else {
            return nil
        }
        guard case .drmSyncobj(let acquirePoint) = acquireSynchronization else {
            return nil
        }
        guard acquirePoint.windowID == window.id,
            importedExternalSyncTimelineIDs.contains(acquirePoint.timelineID),
            acquirePoint.value > 0
        else {
            throw WaylandGraphicsError.unavailable(.externalSynchronizationUnavailable)
        }

        let slotID = try externalBufferSlotID(for: externalBuffer)
        let releasePointValue = try requireExternalReleasePoint(for: externalBuffer)
        let syncState = GPUSubmittedBufferSyncState(
            slotID: slotID,
            acquirePoint: GPUSyncPoint(
                timeline: GPUSyncTimeline(acquirePoint.timelineID.rawValue),
                point: RawSyncobjTimelinePoint(acquirePoint.value)
            ),
            releasePoint: GPUSyncPoint(
                timeline: releaseTimeline.identity,
                point: RawSyncobjTimelinePoint(releasePointValue)
            )
        )
        return (
            presentation: .explicit(syncState),
            explicitReleaseTimeline: releaseTimeline
        )
    }

    private func requireExternalReleasePoint(
        for externalBuffer: WaylandGraphicsExternalBuffer
    ) throws -> UInt64 {
        guard
            let releasePoint = externalBufferRegistry.nextReleasePoint(
                for: externalBuffer.id
            )
        else {
            throw externalBufferUnavailable(externalBuffer)
        }

        return releasePoint
    }

    private func monitorExternalExplicitRelease(
        submissionID: WaylandGraphicsExternalSubmissionID,
        slotID: GBMBufferPoolSlotID,
        syncState: GPUSubmittedBufferSyncState,
        releaseTimeline: WaylandGraphicsExternalReleaseTimeline
    ) {
        let presenter = externalBufferPresenter
        let releaseRegistry = externalReleaseRegistry
        let releaseRetirementNotifier = externalReleaseRetirementNotifier
        // swiftlint:disable:next no_unstructured_task
        let monitorTask = Task {
            do {
                while !Task.isCancelled {
                    if try releaseTimeline.releasePointIsSignaled(syncState.releasePoint.point) {
                        try presenter.recordExplicitReleaseSignal(slotID: slotID)
                        releaseRegistry.finish(
                            submissionID: submissionID,
                            result: .released
                        )
                        releaseRetirementNotifier.notify()
                        return
                    }
                    try await Task.sleep(
                        nanoseconds: WaylandGraphicsExternalReleaseTimeline.pollSleepNanoseconds
                    )
                }
                releaseRegistry.finish(
                    submissionID: submissionID,
                    result: .retired(.backingClosed)
                )
            } catch is CancellationError {
                releaseRegistry.finish(
                    submissionID: submissionID,
                    result: .retired(.backingClosed)
                )
            } catch {
                releaseRegistry.finish(
                    submissionID: submissionID,
                    result: .failed(.explicitSyncReleaseFailed)
                )
            }
        }
        releaseRegistry.trackMonitorTask(monitorTask, submissionID: submissionID)
    }

    private func handleExternalSurfaceFeedbackFailure(
        _ error: GraphicsPreviewSurfaceFeedbackError
    ) throws {
        _ = error
        let unavailableReason = WaylandGraphicsUnavailableReason.surfaceFeedbackUnavailable
        backingRuntimePath = Self.runtimePath(
            Self.runtimePath(backingRuntimePath, backingUnavailable: unavailableReason),
            surfaceFeedback: .failed(unavailableReason)
        )
        throw WaylandGraphicsError.unavailable(unavailableReason)
    }

    private func nextExternalBufferSlotID() throws -> GBMBufferPoolSlotID {
        let slotID = try GBMBufferPoolSlotID(nextExternalBufferSlotRawValue)
        nextExternalBufferSlotRawValue += 1
        return slotID
    }

    private func nextExternalBufferID() -> WaylandGraphicsExternalBufferID {
        let id = WaylandGraphicsExternalBufferID(rawValue: nextExternalBufferIDRawValue)
        nextExternalBufferIDRawValue += 1
        return id
    }

    private func nextExternalSubmissionID() -> WaylandGraphicsExternalSubmissionID {
        let id = WaylandGraphicsExternalSubmissionID(
            rawValue: nextExternalSubmissionRawValue
        )
        nextExternalSubmissionRawValue += 1
        return id
    }

    private func nextExternalSyncTimelineID() -> WaylandGraphicsExternalSyncTimelineID {
        let id = WaylandGraphicsExternalSyncTimelineID(
            rawValue: nextExternalSyncTimelineRawValue
        )
        nextExternalSyncTimelineRawValue += 1
        return id
    }

    private func refreshRuntimePathFromExternalBuffer(
        backing: WaylandGraphicsRuntimeStatus
    ) {
        backingRuntimePath = Self.runtimePath(
            backingRuntimePath,
            externalBufferBacking: backing
        )
    }

    private func applyExternalSynchronizationStatus(
        configuration effectiveConfiguration: WaylandGraphicsConfiguration,
        synchronization: GPUBufferSubmissionSynchronization
    ) {
        switch synchronization {
        case .implicit:
            guard effectiveConfiguration.synchronizationPolicy == .preferExplicit else {
                return
            }

            backingRuntimePath = Self.runtimePath(
                backingRuntimePath,
                explicitSync: .fallback(.externalSynchronizationUnavailable)
            )
        case .explicit:
            backingRuntimePath = Self.runtimePath(
                backingRuntimePath,
                explicitSync: .active
            )
        }
    }

    private func externalGraphicsError(_ error: any Error) -> any Error {
        if let graphicsError = error as? WaylandGraphicsError {
            return graphicsError
        }
        if let presenterError = error as? GPUWindowPresenterError {
            if let committed = presenterError.committedFrameFailure {
                return WaylandGraphicsError.unavailable(
                    WaylandGraphicsUnavailableReason(committed)
                )
            }
            switch presenterError {
            case .submitConstraints(let error):
                return WaylandGraphicsError.unavailable(
                    WaylandGraphicsUnavailableReason(GPUBackingFailure(error))
                )
            case .metadata(let error):
                return WaylandGraphicsError.unavailable(
                    WaylandGraphicsUnavailableReason(
                        GPUBackingFailure.metadataRequiredButUnavailable(error)
                    )
                )
            default:
                return WaylandGraphicsError.unavailable(.commitFailed)
            }
        }
        if error is RuntimeError {
            return WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }
        return error
    }

    private func finishCommittedSubmissionFailure() {
        do { try leaseState.finishSubmission() } catch { leaseState.failSubmission() }
    }

    private func rejectSoftwareSubmissionWhenUnavailable(
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) throws {
        let shouldReject =
            switch effectiveConfiguration.presentationMode {
            case .software:
                false
            case .externalGPU:
                true
            case .managedGPU:
                if effectiveConfiguration.fallbackPolicy == .requireGPU {
                    true
                } else {
                    switch effectiveConfiguration.synchronizationPolicy {
                    case .implicitOnly:
                        false
                    case .preferExplicit:
                        Self.explicitSyncBlocksSoftwareFallback(
                            backingRuntimePath.explicitSync
                        )
                    case .requireExplicit:
                        true
                    }
                }
            }

        guard !shouldReject else {
            let reason = WaylandGraphicsUnavailableReason.managedGPUSubmissionUnavailable
            backingRuntimePath = Self.runtimePath(backingRuntimePath, backingUnavailable: reason)
            throw WaylandGraphicsError.unavailable(reason)
        }
    }

    private func applyMetadataFallbacks(_ fallbacks: WaylandGraphicsMetadataFallbacks) {
        if !fallbacks.isEmpty { backingRuntimePath = fallbacks.applying(to: backingRuntimePath) }
    }

    private func applyPacingSelection(_ selection: GPUFramePacingPolicySelection) {
        backingRuntimePath = Self.runtimePath(backingRuntimePath, pacingSelection: selection)
    }

    @discardableResult
    private func refreshRuntimePathFromManagedGPU(
        backing: WaylandGraphicsRuntimeStatus
    ) -> Bool {
        guard let managedGPUBacking,
            let capabilities = managedGPUBacking.surfaceCapabilities
        else {
            return false
        }

        backingRuntimePath = WaylandGraphicsRuntimePath(
            gpuSnapshot: managedGPUBacking.runtimePathSnapshot,
            capabilities: capabilities,
            backing: backing
        )
        return true
    }

    private func frameResult(
        operation: WaylandGraphicsFrameSubmissionOperation,
        size: PositivePixelSize,
        metadata: WaylandGraphicsFrameMetadata,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) -> WaylandGraphicsFrameResult {
        WaylandGraphicsFrameResult(
            runtimePath: backingRuntimePath,
            operation: operation.graphicsSubmissionOperation,
            size: size,
            metadata: metadata,
            schedule: WaylandGraphicsFrameSchedule(
                configuration: effectiveConfiguration
            ),
            presentationFeedbackRequested: shouldRequestPresentationFeedback(
                configuration: effectiveConfiguration
            ),
            synchronizationPolicy: effectiveConfiguration.synchronizationPolicy,
            pacingPolicy: effectiveConfiguration.pacingPolicy
        )
    }
}

extension WaylandGraphicsWindowBackingStorage {
    package func closeForTesting() async throws {
        try await close()
    }

    package func externalBufferSubmittedSlotRawValuesForTesting() -> [Int] {
        externalBufferPresenter.outstandingSubmittedSlotIDs.map(\.rawValue)
    }

    package func externalBufferAvailableSlotRawValuesForTesting() -> [Int] {
        externalBufferPresenter.availableSlotIDs.map(\.rawValue)
    }
}
