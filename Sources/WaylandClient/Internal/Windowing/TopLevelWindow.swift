// swiftlint:disable file_length

import Glibc
import WaylandRaw

private struct TopLevelWindowRoleResources {
    let xdgSurface: RawXDGSurface
    let topLevel: RawXDGTopLevel
    var decoration: RawXDGToplevelDecoration?
    let xdgSurfaceOwner: XDGSurfaceOwner
    let topLevelOwner: XDGTopLevelOwner
    var decorationOwner: XDGDecorationOwner?

    mutating func destroy() {
        topLevelOwner.cancel()
        decorationOwner?.cancel()
        decoration?.destroy()
        decoration = nil
        decorationOwner = nil

        topLevel.destroy()

        xdgSurfaceOwner.cancel()
        xdgSurface.destroy()
    }
}

// swiftlint:disable:next type_body_length
package final class TopLevelWindow {
    package static let defaultConfigureTimeoutMS: Int32 = 1_000

    package let id: WindowID

    private let connection: RawDisplayConnection
    private let configuration: WindowConfiguration
    private let initialConfigurePump: (Int32) throws -> Void
    private let configureState: XDGConfigureState
    private let surface: RawSurface

    private let failureSink: any WindowFailureSink
    private var model: WindowModel
    private var surfaceRuntime = SurfaceRuntime<TopLevelWindowRoleResources>(
        role: .toplevelWindow
    )
    private var pendingFrameRegistration: FrameCallbackRegistration?
    private var nextPresentationFeedbackID: UInt64 = 1
    private var pendingPresentationFeedbacks:
        [SurfacePresentationIdentity: RawPresentationFeedback] = [:]

    #if DEBUG
        private var testingInteractionSeatsByID: [SeatID: RawSeat] = [:]
    #endif

    package var onClose: (() -> Void)?
    package var onCloseRequested: (() -> Void)?
    package var onClosed: (() -> Void)?
    package var onRedrawRequested: (() -> Void)?
    package var onOutputMembershipChanged: (([OutputID]) -> Void)?

    package init(
        id windowID: WindowID,
        connection rawConnection: RawDisplayConnection,
        configuration windowConfiguration: WindowConfiguration = .default,
        failureSink windowFailureSink: any WindowFailureSink = DefaultWindowFailureSink(),
        initialConfigurePump pumpEvents: ((Int32) throws -> Void)? = nil
    ) throws {
        id = windowID
        connection = rawConnection
        configuration = windowConfiguration
        failureSink = windowFailureSink
        initialConfigurePump =
            pumpEvents
            ?? { timeoutMilliseconds in
                try rawConnection.pumpEvents(timeoutMilliseconds: timeoutMilliseconds)
            }
        let globals = try rawConnection.bindRequiredGlobals()
        configureState = .init()
        surface = try globals.compositor.createSurface()
        model = WindowModel(
            id: windowID,
            fallbackSize: windowConfiguration.initialSize
        )

        configureState.setSurfaceConfigureHandler { [weak self] in
            self?.markNeedsRedraw()
        }

        surfaceRuntime.setPresentationFeedbackCapability(
            globals.extensions.presentation.presentationFeedbackCapabilityStatus
        )
        surfaceRuntime.setDmabufCapability(
            globals.extensions.linuxDmabuf.surfaceDmabufCapability
        )
        try installScaleObjects(globals: globals)
        try assignXDGRole(globals: globals)
    }

    package var surfaceID: RawObjectID {
        connection.preconditionIsOwnerThread()
        return surface.objectID
    }

    package var closeRequestPolicy: CloseRequestPolicy {
        configuration.closeRequestPolicy
    }

    deinit {
        close()
    }

    private func assignXDGRole(globals: BoundGlobals) throws {
        let newXDGSurface = try globals.xdgWMBase.getSurface(for: surface)
        let newTopLevel = try newXDGSurface.getTopLevel()

        newTopLevel.setTitle(configuration.title.value)
        newTopLevel.setAppID(configuration.appID.value)

        let newXDGSurfaceOwner = XDGSurfaceOwner(
            configureState: configureState,
            invariantFailureSink: connection.invariantFailureSink
        )
        try newXDGSurfaceOwner.install(on: newXDGSurface)

        let newTopLevelOwner = XDGTopLevelOwner(
            configureState: configureState,
            invariantFailureSink: connection.invariantFailureSink
        )
        try newTopLevelOwner.install(on: newTopLevel) { [weak self] in
            guard let self else { return }

            handleCloseRequested()
        }

        let decorationObjects = try createDecorationObjectsIfAvailable(
            globals: globals,
            topLevel: newTopLevel
        )

        try surfaceRuntime.installRoleResources(
            TopLevelWindowRoleResources(
                xdgSurface: newXDGSurface,
                topLevel: newTopLevel,
                decoration: decorationObjects?.decoration,
                xdgSurfaceOwner: newXDGSurfaceOwner,
                topLevelOwner: newTopLevelOwner,
                decorationOwner: decorationObjects?.owner
            )
        )

        try interpretWindowEffects(model.reduce(.roleObjectsCreated))
        surface.commit()
        try interpretWindowEffects(model.reduce(.initialCommitSent))
    }

    private struct DecorationObjects {
        let decoration: RawXDGToplevelDecoration
        let owner: XDGDecorationOwner
    }

    private func createDecorationObjectsIfAvailable(
        globals: BoundGlobals,
        topLevel: RawXDGTopLevel
    ) throws -> DecorationObjects? {
        let manager: RawXDGDecorationManager
        switch globals.extensions.xdgDecorationManager {
        case .bound(let boundManager):
            manager = boundManager
        case .missing:
            return try recordDecorationUnavailable(.managerMissing)
        case .unsupportedVersion(let advertised, let minimum):
            return try recordDecorationUnavailable(
                .unsupportedManagerVersion(advertised: advertised, minimum: minimum)
            )
        }

        let newDecoration = try manager.getTopLevelDecoration(for: topLevel)
        let newOwner = XDGDecorationOwner(
            configureState: configureState,
            invariantFailureSink: connection.invariantFailureSink
        )

        do {
            try newOwner.install(on: newDecoration)
            try interpretWindowEffects(
                model.reduce(.decorationObjectCreated(configuration.decorationPreference))
            )
            requestDecorationPreference(configuration.decorationPreference, on: newDecoration)
            try interpretWindowEffects(
                model.reduce(.decorationPreferenceRequested(configuration.decorationPreference))
            )
            return DecorationObjects(decoration: newDecoration, owner: newOwner)
        } catch {
            newOwner.cancel()
            newDecoration.destroy()
            throw error
        }
    }

    private func requestDecorationPreference(
        _ preference: WindowDecorationPreference,
        on decoration: RawXDGToplevelDecoration
    ) {
        DecorationModeRequest(preference: preference).apply(to: decoration)
    }

    private func installScaleObjects(globals: BoundGlobals) throws {
        scaleInstallation = try SurfaceScaleInstallation.install(
            globals: globals,
            surface: surface,
            invariantFailureSink: connection.invariantFailureSink,
            callbacks: SurfaceScaleInstallationCallbacks(
                onPreferredBufferScale: { [weak self] factor in
                    self?.handlePreferredBufferScale(factor)
                },
                onPreferredFractionalScale: { [weak self] scale in
                    self?.handlePreferredFractionalScale(scale)
                },
                onFractionalScaleUnavailable: { [weak self] in
                    self?.reportFractionalScaleUnavailableBecauseViewporterIsMissing()
                },
                onOutputEnter: { [weak self] output in
                    self?.handleSurfaceEnteredOutput(output)
                },
                onOutputLeave: { [weak self] output in
                    self?.handleSurfaceLeftOutput(output)
                }
            )
        )
    }

    private func reportFractionalScaleUnavailableBecauseViewporterIsMissing() {
        failureSink.reportWindowFailure(
            .diagnostic(
                WindowDiagnostic(
                    windowID: id,
                    payload: .scale(
                        WindowScaleDiagnostic(
                            operation: .fractionalScaleUnavailable,
                            reason: .viewporterMissing
                        )
                    )
                )
            )
        )
    }

    private func recordDecorationUnavailable(
        _ reason: DecorationUnavailableReason
    ) throws -> DecorationObjects? {
        try interpretWindowEffects(model.reduce(.decorationUnavailable(reason)))
        reportDecorationUnavailableIfNeeded(reason: reason)
        return nil
    }

    private func reportDecorationUnavailableIfNeeded(reason: DecorationUnavailableReason) {
        guard configuration.decorationPreference.shouldReportMissingDecorationManager else {
            return
        }

        failureSink.reportWindowFailure(
            .diagnostic(
                WindowDiagnostic(
                    windowID: id,
                    payload: .decoration(
                        WindowDecorationDiagnostic(
                            operation: .decorationUnavailable,
                            reason: WindowDecorationUnavailableReason(reason)
                        )
                    )
                )
            )
        )
    }

    private func waitForInitialConfigure(
        timeoutMilliseconds: Int32
    ) throws -> ResolvedWindowConfiguration {
        _ = try Milliseconds(timeoutMilliseconds)

        let timeout = Int64(max(timeoutMilliseconds, 0))
        let deadline = try monotonicMilliseconds() + timeout
        let pollMilliseconds: Int32 = 50

        while !configureState.hasReceivedInitialConfigure, !model.isClosed {
            let remainingMilliseconds = deadline - (try monotonicMilliseconds())
            guard remainingMilliseconds > 0 else {
                try interpretWindowEffects(
                    model.reduce(.initialConfigureTimedOut(milliseconds: timeoutMilliseconds))
                )
                throw ClientError.window(
                    id,
                    .initialConfigureTimedOut(milliseconds: timeoutMilliseconds)
                )
            }

            let boundedRemaining = Int32(min(remainingMilliseconds, Int64(Int32.max)))
            let pumpTimeout = min(boundedRemaining, pollMilliseconds)
            try initialConfigurePump(pumpTimeout)
            try configureState.throwPendingErrorIfAny()
        }

        guard let configure = try consumeLatestConfigureIfAvailable() else {
            throw ClientError.window(
                id,
                .invalidLifecycleTransition(.mapBeforeInitialConfigure)
            )
        }

        return configure
    }

    private func consumeLatestConfigureIfAvailable() throws -> ResolvedWindowConfiguration? {
        try configureState.throwPendingErrorIfAny()

        guard let sequence = configureState.consumeLatestConfigure() else {
            return nil
        }

        let configureEvent: WindowConfigureEvent
        do {
            configureEvent = try WindowConfigureEvent(
                sequence: sequence,
                previousSize: model.currentConfiguration?.size,
                fallbackSize: model.fallbackSize
            )
        } catch let error as WindowError {
            throw ClientError.window(id, error)
        }
        surfaceRuntime.recordConfigureReceived(serial: configureEvent.serial)
        try interpretWindowEffects(model.reduce(.configureReceived(configureEvent)))
        return model.currentConfiguration
    }

    private func bufferPool(for size: PositivePixelSize) throws -> RawSharedMemoryPool {
        try surfaceRuntime.sharedMemoryPool(for: size) {
            guard let globals = connection.boundGlobals else {
                throw ClientError.windowCreationFailed(.requiredGlobalsNotBound)
            }

            return try globals.sharedMemory.createPool(
                width: size.width.rawValue,
                height: size.height.rawValue,
                bufferCount: configuration.bufferCount.rawValue
            ) { [weak self] in
                self?.handleBufferReleased()
            }
        }
    }

    private func dropReleasedRetiredPools() {
        surfaceRuntime.dropReleasedRetiredBufferPools()
    }

    private func retireSwapchain() {
        surfaceRuntime.retireSharedMemoryPools(reason: .windowClosed)
    }

    private func handleCloseRequested() {
        do {
            try interpretWindowEffects(
                model.reduce(
                    .compositorCloseRequested(policy: configuration.closeRequestPolicy)
                )
            )
        } catch let error as ClientError {
            reportCallbackFailure(operation: .closeRequested, error: error)
        } catch {
            reportCallbackFailure(operation: .closeRequested, error: error)
        }
    }

    private func drawAndPresent(
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> RedrawOutcome {
        guard !model.isClosed else { return .skippedClosed }

        let effects = try model.reduce(
            .redrawRequestConsumed(bufferAvailability: try redrawBufferAvailability())
        )
        return try interpretPresentationEffects(effects, draw)
    }

    // swiftlint:disable:next function_body_length
    private func performSoftwarePresent(
        _ request: PresentationRequest,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> RedrawOutcome {
        try interpretWindowEffects(
            model.reduce(.presentationStarted(request))
        )

        do {
            guard pendingFrameRegistration == nil else {
                failActivePresentation(
                    generation: request.generation,
                    error: .frameCallbackRequest("frame callback is still pending")
                )
                return .skippedPendingFrame
            }

            let geometry = try surfaceGeometry(logicalSize: request.configuration.size)
            let pool = try bufferPool(for: geometry.bufferSize)
            dropReleasedRetiredPools()

            guard var drawingBuffer = pool.acquireDrawingBuffer() else {
                try interpretWindowEffects(model.reduce(.presentationBlockedByBuffer))
                return .waitingForBuffer
            }

            do {
                try unsafe drawingBuffer.withUnsafeMutableBytes { bytes in
                    let frame = try unsafe SoftwareFrame(
                        width: drawingBuffer.width,
                        height: drawingBuffer.height,
                        stride: drawingBuffer.stride,
                        geometry: SoftwareFrameGeometry(surface: geometry),
                        bytes: bytes
                    )
                    try draw(frame)
                }
            } catch {
                failActivePresentation(
                    generation: request.generation,
                    error: .userDraw(String(describing: error))
                )
                drawingBuffer.discard()
                throw error
            }

            guard !model.isClosed else {
                try interpretWindowEffects(model.reduce(.transientStateReset))
                drawingBuffer.discard()
                return .skippedClosed
            }

            let preparedCommit: PreparedSurfaceFrameCommit
            do {
                preparedCommit = try SurfaceFrameCommitter.prepare(
                    SurfaceFrameCommitRequest(
                        surface: surface,
                        scaleInstallation: scaleInstallation,
                        generation: request.generation,
                        geometry: geometry
                    ),
                    runtime: &surfaceRuntime,
                )
            } catch {
                failActivePresentation(
                    generation: request.generation,
                    error: .surfaceCommit(String(describing: error))
                )
                drawingBuffer.discard()
                throw error
            }

            do {
                pendingFrameRegistration = try SurfaceFrameCommitter.requestFrameCallback(
                    on: surface,
                    runtime: &surfaceRuntime,
                    generation: request.generation
                ) { [weak self] in
                    self?.handleFrameDone()
                }
            } catch {
                failActivePresentation(
                    generation: request.generation,
                    error: .frameCallbackRequest(String(describing: error))
                )
                drawingBuffer.discard()
                throw error
            }

            do {
                try SurfaceFrameCommitter.recordPreparedCommit(
                    preparedCommit,
                    runtime: &surfaceRuntime
                )
                let buffer = drawingBuffer.markBusy(commitGeneration: request.generation)
                SurfaceFrameCommitter.commit(preparedCommit, buffer: buffer)
            } catch {
                pendingFrameRegistration = nil
                surfaceRuntime.cancelFrameCallback()
                drawingBuffer.discard()
                throw error
            }

            try interpretWindowEffects(
                model.reduce(
                    .presentationSucceeded(
                        generation: request.generation,
                        bufferAvailability: try redrawBufferAvailability()
                    )
                )
            )
            return .presented
        } catch {
            failPresentationIfStillActive(
                generation: request.generation,
                error: .surfaceCommit(String(describing: error))
            )
            throw error
        }
    }

    private func failPresentationIfStillActive(
        generation: UInt64,
        error: PresentationError
    ) {
        guard case .drawing(let request) = model.presentation,
            request.generation == generation
        else {
            return
        }

        failActivePresentation(
            generation: generation,
            error: error
        )
    }

    private func failActivePresentation(
        generation: UInt64,
        error: PresentationError
    ) {
        do {
            try interpretWindowEffects(
                model.reduce(.presentationFailed(generation: generation, error))
            )
        } catch ClientError.window(id, .presentationFailed(let reportedError))
            where reportedError == error
        {
            // presentationFailed resets model state before reporting the presentation error.
        } catch {
            preconditionFailure("Unexpected presentation failure error: \(error)")
        }
    }

    private func monotonicMilliseconds() throws -> Int64 {
        var timestamp = timespec()
        guard unsafe clock_gettime(CLOCK_MONOTONIC, &timestamp) == 0 else {
            throw ClientError.windowCreationFailed(.clockGetTimeFailed(errno: errno))
        }

        return Int64(timestamp.tv_sec) * 1_000 + Int64(timestamp.tv_nsec) / 1_000_000
    }

    private func resetTransientState() {
        do {
            surfaceRuntime.resetTransientTransactionState()
            _ = try model.reduce(.transientStateReset)
        } catch let error as ClientError {
            reportCallbackFailure(operation: .transientStateReset, error: error)
        } catch {
            reportCallbackFailure(operation: .transientStateReset, error: error)
        }
    }

    private func reportCallbackFailure(operation: WindowCallbackOperation, error: any Error) {
        failureSink.reportWindowFailure(
            WindowFailureClassifier.classify(
                windowID: id,
                operation: operation,
                error: error
            )
        )
    }
}

extension TopLevelWindow {
    private var roleResources: TopLevelWindowRoleResources? {
        get { surfaceRuntime.roleResources }
        set { surfaceRuntime.roleResources = newValue }
    }

    private var scaleInstallation: SurfaceScaleInstallation {
        get { surfaceRuntime.scaleInstallation }
        set { surfaceRuntime.scaleInstallation = newValue }
    }

    private func activeTopLevel(for event: String) throws -> RawXDGTopLevel {
        guard let topLevel = roleResources?.topLevel else {
            throw ClientError.window(
                id,
                .invalidLifecycleTransition(
                    .invalidTransition(from: "missing xdg_toplevel", event: event)
                )
            )
        }

        return topLevel
    }

    private func interactionSeat(for seatID: SeatID) throws -> RawSeat {
        #if DEBUG
            if let seat = testingInteractionSeatsByID[seatID] {
                return seat
            }
        #endif

        let globals = try connection.bindRequiredGlobals()
        guard
            let seat = globals.seatRegistry.seat(
                for: RawSeatID(seatID)
            )
        else {
            throw ClientError.invalidWindowState(.unknownWindowInteractionSeat(seatID))
        }

        return seat
    }

    private func fullscreenOutput(for outputID: OutputID?) throws -> RawOutput? {
        guard let outputID else { return nil }

        let globals = try connection.bindRequiredGlobals()
        guard
            let output = globals.outputRegistry.output(
                for: RawOutputID(outputID)
            )
        else {
            throw ClientError.invalidWindowState(.unknownWindowFullscreenOutput(outputID))
        }

        return output
    }

    #if DEBUG
        package func installInteractionSeatForTesting(
            id seatID: SeatID,
            pointerAddress: Int
        ) throws -> UInt {
            if let existing = testingInteractionSeatsByID[seatID] {
                return existing.pointerAddressForTesting
            }

            let seat = try RawSeat.testingNoopSeatForRequestRecording(
                id: RawSeatID(seatID),
                pointerAddress: pointerAddress
            )
            testingInteractionSeatsByID[seatID] = seat
            return seat.pointerAddressForTesting
        }

        package func removeInteractionSeatForTesting(_ seatID: SeatID) {
            testingInteractionSeatsByID.removeValue(forKey: seatID)?.destroy()
        }
    #endif

    private var outputIDsOnOwnerThread: [OutputID] {
        guard let outputRegistry = connection.boundGlobals?.outputRegistry else { return [] }

        return surfaceRuntime.currentOutputIDs { outputRegistry.output(for: $0) != nil }
    }
}

extension TopLevelWindow {
    private func handleFrameDone() {
        do {
            _ = try surfaceRuntime.completeFrameCallback()
        } catch {
            reportCallbackFailure(operation: .frameDone, error: error)
        }
        pendingFrameRegistration = nil
        dropReleasedRetiredPools()

        guard !model.isClosed else {
            resetTransientState()
            return
        }

        do {
            try interpretWindowEffects(
                model.reduce(.frameBecameReady(bufferAvailability: try redrawBufferAvailability()))
            )
        } catch let error as ClientError {
            reportCallbackFailure(operation: .frameDone, error: error)
        } catch {
            reportCallbackFailure(operation: .frameDone, error: error)
        }
    }

    private func handleBufferReleased() {
        connection.preconditionIsOwnerThread()
        dropReleasedRetiredPools()

        guard !model.isClosed, model.redraw.isWaitingForBuffer else { return }

        do {
            try interpretWindowEffects(
                model.reduce(
                    .bufferBecameAvailable(bufferAvailability: try redrawBufferAvailability())
                )
            )
        } catch let error as ClientError {
            reportCallbackFailure(operation: .bufferReleased, error: error)
        } catch {
            reportCallbackFailure(operation: .bufferReleased, error: error)
        }
    }

    private func handlePreferredBufferScale(_ factor: Int32) {
        guard !model.isClosed else {
            resetTransientState()
            return
        }

        do {
            let logicalSize = currentLogicalSize
            guard
                try surfaceRuntime.updateScaleInstallation({ scaleInstallation in
                    try scaleInstallation.updatePreferredBufferScale(
                        factor,
                        logicalSize: logicalSize
                    )
                })
            else { return }
            try markNeedsRedraw(bufferAvailability: .available)
        } catch let error as WindowError {
            reportCallbackFailure(
                operation: .surfaceScaleChanged,
                error: ClientError.window(id, error)
            )
        } catch {
            reportCallbackFailure(operation: .surfaceScaleChanged, error: error)
        }
    }

    private func handlePreferredFractionalScale(_ scale: UInt32) {
        guard !model.isClosed else {
            resetTransientState()
            return
        }

        do {
            let logicalSize = currentLogicalSize
            guard
                try surfaceRuntime.updateScaleInstallation({ scaleInstallation in
                    try scaleInstallation.updatePreferredFractionalScale(
                        scale,
                        logicalSize: logicalSize
                    )
                })
            else { return }
            try markNeedsRedraw(bufferAvailability: .available)
        } catch let error as WindowError {
            reportCallbackFailure(
                operation: .surfaceScaleChanged,
                error: ClientError.window(id, error)
            )
        } catch {
            reportCallbackFailure(operation: .surfaceScaleChanged, error: error)
        }
    }

    private func handleSurfaceEnteredOutput(_ output: RawOutputPointerIdentity) {
        guard !model.isClosed else { return }

        guard
            let outputID = connection.boundGlobals?.outputRegistry.outputID(for: output)
        else {
            return
        }

        guard surfaceRuntime.enterOutput(outputID) else { return }

        onOutputMembershipChanged?(outputIDsOnOwnerThread)
    }

    private func handleSurfaceLeftOutput(_ output: RawOutputPointerIdentity) {
        guard !model.isClosed else { return }

        guard
            let outputID = connection.boundGlobals?.outputRegistry.outputID(for: output)
        else {
            return
        }

        guard surfaceRuntime.leaveOutput(outputID) else { return }

        onOutputMembershipChanged?(outputIDsOnOwnerThread)
    }

    private func markNeedsRedraw() {
        do {
            try markNeedsRedraw(bufferAvailability: try redrawBufferAvailability())
        } catch let error as ClientError {
            reportCallbackFailure(operation: .markNeedsRedraw, error: error)
        } catch {
            reportCallbackFailure(operation: .markNeedsRedraw, error: error)
        }
    }

    private func markNeedsRedraw(bufferAvailability: RedrawBufferAvailability) throws {
        guard !model.isClosed else {
            resetTransientState()
            return
        }

        try interpretWindowEffects(
            model.reduce(.contentInvalidated(bufferAvailability: bufferAvailability))
        )
    }

    private var isDirty: Bool {
        model.redraw.isDirty
    }

    private var currentLogicalSize: PositiveLogicalSize {
        model.currentConfiguration?.size ?? configuration.initialSize
    }

    private func currentSurfaceGeometry() throws -> SurfaceGeometry {
        try surfaceGeometry(logicalSize: currentLogicalSize)
    }

    private func surfaceGeometry(logicalSize: PositiveLogicalSize) throws -> SurfaceGeometry {
        do {
            return try scaleInstallation.geometry(logicalSize: logicalSize)
        } catch let error as WindowError {
            throw ClientError.window(id, error)
        }
    }

    private func redrawBufferAvailability() throws -> RedrawBufferAvailability {
        surfaceRuntime.redrawBufferAvailability(
            matching: try currentSurfaceGeometry().bufferSize.rawSize
        )
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func interpretWindowEffects(_ effects: [WindowEffect]) throws {
        for effect in effects {
            switch effect {
            case .ackConfigure(let serial):
                guard let activeXDGSurface = roleResources?.xdgSurface else {
                    throw ClientError.window(
                        id,
                        .invalidLifecycleTransition(
                            .invalidTransition(from: "missing xdg_surface", event: "ackConfigure")
                        )
                    )
                }
                try surfaceRuntime.acknowledgeConfigure(serial: serial)
                activeXDGSurface.ackConfigure(serial: serial)
            case .publishCloseRequested:
                onCloseRequested?()
            case .publishClosed:
                onClosed?()
                onClosed = nil
            case .publishRedrawRequested:
                onRedrawRequested?()
            case .publishDiagnostic(let diagnostic):
                failureSink.reportWindowFailure(.diagnostic(diagnostic))
            case .cancelFrameCallback:
                pendingFrameRegistration = nil
                surfaceRuntime.cancelFrameCallback()
            case .performSoftwarePresent:
                throw ClientError.window(
                    id,
                    .invalidLifecycleTransition(
                        .invalidTransition(
                            from: "effect interpreter without draw closure",
                            event: "performSoftwarePresent"
                        )
                    )
                )
            case .retireSwapchain:
                retireSwapchain()
            case .destroyRoleObjects:
                destroyRoleObjects()
            case .destroySurface:
                destroyScaleObjects()
                surface.destroy()
                try surfaceRuntime.markSurfaceDestroyed()
            }
        }
    }

    private func interpretPresentationEffects(
        _ effects: [WindowEffect],
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> RedrawOutcome {
        var outcome = RedrawOutcome.skippedPendingFrame

        for effect in effects {
            switch effect {
            case .performSoftwarePresent(let request):
                outcome = try performSoftwarePresent(request, draw)
            default:
                try interpretWindowEffects([effect])
            }
        }

        return effects.isEmpty ? .skippedPendingFrame : outcome
    }

    private func destroyRoleObjects() {
        onClose?()
        onClose = nil
        onCloseRequested = nil
        onRedrawRequested = nil
        onOutputMembershipChanged = nil
        cancelPresentationFeedbacks()

        var removedRoleResources = surfaceRuntime.removeRoleResources()
        removedRoleResources?.destroy()
    }

    private func destroyScaleObjects() {
        surfaceRuntime.destroyScaleInstallation()
    }
}

extension TopLevelWindow {
    #if DEBUG
        package var topLevelPointerAddressForTesting: UInt? {
            roleResources?.topLevel.pointerAddressForTesting
        }

        package var surfacePointerAddressForTesting: UInt {
            surface.pointerAddressForTesting
        }
    #endif

    package var isClosedOnOwnerThread: Bool {
        connection.preconditionIsOwnerThread()
        return model.isClosed
    }

    package var needsRedrawOnOwnerThread: Bool {
        connection.preconditionIsOwnerThread()
        return isDirty
    }

    package var decorationModeOnOwnerThread: WindowDecorationMode {
        connection.preconditionIsOwnerThread()
        return model.decorationMode
    }

    package var geometryOnOwnerThread: SurfaceGeometry {
        get throws {
            connection.preconditionIsOwnerThread()
            return try currentSurfaceGeometry()
        }
    }

    package var stateSnapshotOnOwnerThread: WindowStateSnapshot {
        get throws {
            connection.preconditionIsOwnerThread()
            guard let configuration = model.currentConfiguration else {
                throw ClientError.window(
                    id,
                    .invalidLifecycleTransition(.mapBeforeInitialConfigure)
                )
            }

            return WindowStateSnapshot(configuration, outputIDs: outputIDsOnOwnerThread)
        }
    }

    package func markPublishedOnOwnerThread() throws {
        connection.preconditionIsOwnerThread()
        try interpretWindowEffects(model.reduce(.published))
    }

    package func removeOutputMembershipOnOwnerThread(_ outputID: OutputID) {
        connection.preconditionIsOwnerThread()
        guard !model.isClosed else { return }
        guard surfaceRuntime.removeOutput(outputID) else { return }

        onOutputMembershipChanged?(outputIDsOnOwnerThread)
    }

    package func requestRedrawOnOwnerThread() throws {
        connection.preconditionIsOwnerThread()
        markNeedsRedraw()
    }

    package func presentPreviewBufferOnOwnerThread(
        _ buffer: RawSurfaceBuffer
    ) throws -> PreviewBufferPresentationResult {
        connection.preconditionIsOwnerThread()

        guard !model.isClosed else {
            throw ClientError.window(id, .invalidLifecycleTransition(.presentAfterDestroyed))
        }
        guard model.currentConfiguration != nil else {
            throw ClientError.window(id, .invalidLifecycleTransition(.mapBeforeInitialConfigure))
        }
        guard pendingFrameRegistration == nil else {
            throw ClientError.window(id, .invalidLifecycleTransition(.nestedPresentation))
        }
        guard model.presentation == .idle else {
            throw ClientError.window(id, .invalidLifecycleTransition(.nestedPresentation))
        }

        let generation = surfaceRuntime.nextCommitGeneration
        let bufferAvailability = try redrawBufferAvailability()
        let presentationRequest = WindowExternalBufferPresentationRequest(
            buffer: buffer,
            surface: surface,
            scaleInstallation: scaleInstallation,
            generation: generation,
            geometry: try currentSurfaceGeometry()
        ) { [weak self] in
            self?.handleFrameDone()
        }
        let commitPlan = try WindowExternalBufferPresenter.present(
            presentationRequest,
            runtime: &surfaceRuntime,
            pendingFrameRegistration: &pendingFrameRegistration
        )
        try interpretWindowEffects(
            model.reduce(
                .externalPresentationSucceeded(
                    generation: generation,
                    bufferAvailability: bufferAvailability
                )
            )
        )
        return PreviewBufferPresentationResult(
            generation: generation,
            commitPlan: commitPlan
        )
    }

    package func requestPresentationFeedbackOnOwnerThread(
        presentation: RawPresentation,
        outputIDForPresentationSyncOutput:
            @escaping (
                RawOutputPointerIdentity
            ) throws -> OutputID?,
        onFeedback: @escaping (SurfacePresentationFeedback) -> Void
    ) throws {
        connection.preconditionIsOwnerThread()
        guard !model.isClosed else {
            throw ClientError.display(.closed)
        }
        guard model.currentConfiguration != nil else {
            throw ClientError.window(
                id,
                .invalidLifecycleTransition(.mapBeforeInitialConfigure)
            )
        }

        let identity = allocatePresentationFeedbackIdentity()
        let feedback = try presentation.requestFeedback(for: surface) { [weak self] rawEvent in
            self?.handlePresentationFeedback(
                identity,
                event: rawEvent,
                outputIDForPresentationSyncOutput: outputIDForPresentationSyncOutput,
                onFeedback: onFeedback
            )
        }
        pendingPresentationFeedbacks[identity] = feedback
    }

    package func setTitleOnOwnerThread(_ title: WaylandString) throws {
        connection.preconditionIsOwnerThread()
        try activeTopLevel(for: "setTitle").setTitle(title.value)
    }

    package func setAppIDOnOwnerThread(_ appID: NonEmptyWaylandString) throws {
        connection.preconditionIsOwnerThread()
        try activeTopLevel(for: "setAppID").setAppID(appID.value)
    }

    package func setMinimumSizeOnOwnerThread(_ size: PositiveLogicalSize?) throws {
        connection.preconditionIsOwnerThread()
        let topLevel = try activeTopLevel(for: "setMinimumSize")
        topLevel.setMinimumSize(
            width: size?.width.rawValue ?? 0,
            height: size?.height.rawValue ?? 0
        )
    }

    package func setMaximumSizeOnOwnerThread(_ size: PositiveLogicalSize?) throws {
        connection.preconditionIsOwnerThread()
        let topLevel = try activeTopLevel(for: "setMaximumSize")
        topLevel.setMaximumSize(
            width: size?.width.rawValue ?? 0,
            height: size?.height.rawValue ?? 0
        )
    }

    package func requestMaximizeOnOwnerThread() throws {
        connection.preconditionIsOwnerThread()
        try activeTopLevel(for: "requestMaximize").setMaximized()
    }

    package func requestUnmaximizeOnOwnerThread() throws {
        connection.preconditionIsOwnerThread()
        try activeTopLevel(for: "requestUnmaximize").unsetMaximized()
    }

    package func requestFullscreenOnOwnerThread(outputID: OutputID? = nil) throws {
        connection.preconditionIsOwnerThread()
        let output = try fullscreenOutput(for: outputID)
        try activeTopLevel(for: "requestFullscreen").setFullscreen(output: output)
    }

    package func requestExitFullscreenOnOwnerThread() throws {
        connection.preconditionIsOwnerThread()
        try activeTopLevel(for: "requestExitFullscreen").unsetFullscreen()
    }

    package func requestMinimizeOnOwnerThread() throws {
        connection.preconditionIsOwnerThread()
        try activeTopLevel(for: "requestMinimize").setMinimized()
    }

    package func requestInteractiveMoveOnOwnerThread(
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        connection.preconditionIsOwnerThread()
        let topLevel = try activeTopLevel(for: "requestInteractiveMove")
        let seat = try interactionSeat(for: seatID)
        topLevel.move(seat: seat, serial: serial.rawValue)
    }

    package func requestInteractiveResizeOnOwnerThread(
        seatID: SeatID,
        serial: InputSerial,
        edge: WindowResizeEdge
    ) throws {
        connection.preconditionIsOwnerThread()
        let topLevel = try activeTopLevel(for: "requestInteractiveResize")
        let seat = try interactionSeat(for: seatID)
        topLevel.resize(seat: seat, serial: serial.rawValue, edge: edge.rawXDGResizeEdge)
    }

    package func requestWindowMenuOnOwnerThread(
        seatID: SeatID,
        serial: InputSerial,
        position: LogicalOffset
    ) throws {
        connection.preconditionIsOwnerThread()
        let topLevel = try activeTopLevel(for: "requestWindowMenu")
        let seat = try interactionSeat(for: seatID)
        topLevel.showWindowMenu(
            seat: seat,
            serial: serial.rawValue,
            x: position.x,
            y: position.y
        )
    }

    package func dataTransferDragOriginOnOwnerThread() throws -> any DataTransferDragOriginBinding {
        connection.preconditionIsOwnerThread()
        _ = try activeTopLevel(for: "startDrag")
        return LiveDataTransferDragOriginBinding(surface: surface)
    }

    package func createPopupOnOwnerThread(
        id popupID: PopupID,
        configuration popupConfiguration: PopupConfiguration,
        failureSink popupFailureSink: any WindowFailureSink
    ) throws -> PopupRoleSurface {
        connection.preconditionIsOwnerThread()

        guard !model.isClosed else {
            throw ClientError.window(id, .invalidLifecycleTransition(.redrawAfterDestroyed))
        }
        guard model.currentConfiguration != nil else {
            throw ClientError.window(id, .invalidLifecycleTransition(.mapBeforeInitialConfigure))
        }
        guard let activeXDGSurface = roleResources?.xdgSurface else {
            throw ClientError.window(
                id,
                .invalidLifecycleTransition(
                    .invalidTransition(from: "missing xdg_surface", event: "createPopup")
                )
            )
        }

        return try PopupRoleSurface(
            id: popupID,
            parentWindowID: id,
            connection: connection,
            parentXDGSurface: activeXDGSurface,
            configuration: popupConfiguration,
            bufferCount: configuration.bufferCount,
            failureSink: popupFailureSink
        ) { [weak self] timeoutMilliseconds in
            guard let self else {
                throw ClientError.display(.closed)
            }

            try initialConfigurePump(timeoutMilliseconds)
        }
    }

    package func showOnOwnerThread(
        timeoutMilliseconds: Int32 = defaultConfigureTimeoutMS,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        connection.preconditionIsOwnerThread()

        if model.currentConfiguration == nil {
            _ = try waitForInitialConfigure(timeoutMilliseconds: timeoutMilliseconds)
        }

        _ = try drawAndPresent(draw)
    }

    package func redrawOnOwnerThread(
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        connection.preconditionIsOwnerThread()

        guard !model.isClosed else { return }

        _ = try consumeLatestConfigureIfAvailable()
        _ = try drawAndPresent(draw)
    }

    package func closeOnOwnerThread() {
        connection.preconditionIsOwnerThread()

        guard !model.isDestroyed else { return }

        do {
            try interpretWindowEffects(model.reduce(.explicitClose))
        } catch {
            reportCallbackFailure(operation: .close, error: error)
        }
    }

    @available(
        *,
        noasync,
        message: "Read window state from the owner-thread Wayland loop."
    )
    package var isClosed: Bool {
        isClosedOnOwnerThread
    }

    @available(
        *,
        noasync,
        message: "Read window state from the owner-thread Wayland loop."
    )
    package var needsRedraw: Bool {
        needsRedrawOnOwnerThread
    }

    @available(
        *,
        noasync,
        message: "Show windows from the owner-thread Wayland loop."
    )
    package func show(
        timeoutMilliseconds: Int32 = defaultConfigureTimeoutMS,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try showOnOwnerThread(timeoutMilliseconds: timeoutMilliseconds, draw)
    }

    @available(
        *,
        noasync,
        message: "Redraw windows from the owner-thread Wayland loop."
    )
    package func redraw(_ draw: (borrowing SoftwareFrame) throws -> Void) throws {
        try redrawOnOwnerThread(draw)
    }

    @available(
        *,
        noasync,
        message: "Close windows from the owner-thread Wayland loop."
    )
    package func close() {
        closeOnOwnerThread()
    }
}

extension TopLevelWindow {
    private func allocatePresentationFeedbackIdentity() -> SurfacePresentationIdentity {
        defer { nextPresentationFeedbackID += 1 }
        return SurfacePresentationIdentity(rawValue: nextPresentationFeedbackID)
    }

    private func handlePresentationFeedback(
        _ identity: SurfacePresentationIdentity,
        event rawEvent: RawPresentationFeedbackEvent,
        outputIDForPresentationSyncOutput: (RawOutputPointerIdentity) throws -> OutputID?,
        onFeedback: (SurfacePresentationFeedback) -> Void
    ) {
        pendingPresentationFeedbacks.removeValue(forKey: identity)

        do {
            switch rawEvent {
            case .presented(let rawPresented):
                let synchronizedOutput = try rawPresented.synchronizedOutput.flatMap { output in
                    try outputIDForPresentationSyncOutput(output)
                }
                onFeedback(
                    .presented(
                        PresentationFeedback(
                            surface: identity,
                            timestamp: PresentationTimestamp(
                                seconds: rawPresented.timestamp.seconds,
                                nanoseconds: rawPresented.timestamp.nanoseconds
                            ),
                            refreshNanoseconds: rawPresented.refreshNanoseconds == 0
                                ? nil
                                : rawPresented.refreshNanoseconds,
                            sequence: PresentationSequence(
                                value: rawPresented.sequence.value
                            ),
                            flags: PresentationFeedbackFlags(rawValue: rawPresented.flags),
                            synchronizedOutput: synchronizedOutput
                        )
                    )
                )
            case .discarded:
                onFeedback(.discarded(identity))
            }
        } catch {
            reportCallbackFailure(operation: .presentationFeedback, error: error)
        }
    }

    private func cancelPresentationFeedbacks() {
        for feedback in pendingPresentationFeedbacks.values {
            feedback.cancel()
        }
        pendingPresentationFeedbacks.removeAll()
    }
}
