// swiftlint:disable file_length

import Glibc
import WaylandRaw

// swiftlint:disable:next type_body_length
package final class TopLevelWindow {
    package static let defaultConfigureTimeoutMS: Int32 = 1_000

    package let id: WindowID

    private let connection: RawDisplayConnection
    private let configuration: WindowConfiguration
    private let initialConfigurePump: (Int32) throws -> Void
    private let configureState: XDGConfigureState
    private let surface: RawSurface

    private var xdgSurface: RawXDGSurface?
    private var topLevel: RawXDGTopLevel?
    private var decoration: RawXDGToplevelDecoration?
    private var xdgSurfaceOwner: XDGSurfaceOwner?
    private var topLevelOwner: XDGTopLevelOwner?
    private var decorationOwner: XDGDecorationOwner?
    private var buffers: RawSharedMemoryPool?
    private var retiredBufferPools: [RawSharedMemoryPool] = []
    private var pendingFrameRegistration: FrameCallbackRegistration?
    private let failureSink: any WindowFailureSink
    private var model: WindowModel

    package var onClose: (() -> Void)?
    package var onCloseRequested: (() -> Void)?
    package var onClosed: (() -> Void)?
    package var onRedrawRequested: (() -> Void)?

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

        configureState.setSurfaceConfigureHandler { [weak window = self] in
            window?.markNeedsRedraw()
        }

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
        try newTopLevelOwner.install(on: newTopLevel) { [weak window = self] in
            guard let window else { return }

            window.handleCloseRequested()
        }

        let decorationObjects = try createDecorationObjectsIfAvailable(
            globals: globals,
            topLevel: newTopLevel
        )

        xdgSurface = newXDGSurface
        topLevel = newTopLevel
        decoration = decorationObjects?.decoration
        xdgSurfaceOwner = newXDGSurfaceOwner
        topLevelOwner = newTopLevelOwner
        decorationOwner = decorationObjects?.owner

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
        guard let manager = globals.extensions.xdgDecorationManager else {
            try interpretWindowEffects(model.reduce(.decorationUnavailable(.managerMissing)))
            reportDecorationUnavailableIfNeeded(reason: .managerMissing)
            return nil
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
        guard let requestedMode = preference.requestedRawMode else {
            decoration.unsetMode()
            return
        }

        decoration.setMode(requestedMode)
    }

    private func reportDecorationUnavailableIfNeeded(reason: DecorationUnavailableReason) {
        guard configuration.decorationPreference == .preferServerSide else { return }

        failureSink.reportWindowFailure(
            .diagnostic(
                WindowDiagnostic(
                    windowID: id,
                    operation: .decoration(.decorationUnavailable),
                    message: decorationUnavailableMessage(reason)
                )
            )
        )
    }

    private func decorationUnavailableMessage(_ reason: DecorationUnavailableReason) -> String {
        switch reason {
        case .managerMissing:
            "Server-side decoration protocol is unavailable."
        }
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

        try interpretWindowEffects(model.reduce(.configureReceived(sequence)))
        return model.currentConfiguration
    }

    private func bufferPool(for size: PositiveTopLevelSize) throws -> RawSharedMemoryPool {
        try BufferPoolReplacement.pool(
            for: size.rawSize,
            active: &buffers,
            retired: &retiredBufferPools
        ) {
            guard let globals = connection.boundGlobals else {
                throw ClientError.windowCreationFailed("required globals are not bound")
            }

            return try globals.sharedMemory.createPool(
                width: size.width.rawValue,
                height: size.height.rawValue,
                bufferCount: configuration.bufferCount.rawValue
            ) { [weak window = self] in
                window?.handleBufferReleased()
            }
        }
    }

    private func dropReleasedRetiredPools() {
        retiredBufferPools.removeAll { pool in
            !pool.hasBusyBuffers
        }
    }

    private func retireSwapchain() {
        if let activeBuffers = buffers {
            activeBuffers.retire(reason: .windowClosed)
            if activeBuffers.hasBusyBuffers {
                retiredBufferPools.append(activeBuffers)
            }
            buffers = nil
        }

        for pool in retiredBufferPools {
            pool.retire(reason: .windowClosed)
        }
        dropReleasedRetiredPools()
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
            .redrawRequestConsumed(bufferAvailable: redrawBufferAvailable)
        )
        return try interpretPresentationEffects(effects, draw)
    }

    // swiftlint:disable:next function_body_length
    private func performSoftwarePresent(
        _ request: PresentationRequest,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> RedrawOutcome {
        try interpretWindowEffects(
            model.reduce(.presentationStarted(generation: request.generation))
        )

        do {
            guard pendingFrameRegistration == nil else {
                failActivePresentation(
                    generation: request.generation,
                    detail: "frame callback is still pending"
                )
                return .skippedPendingFrame
            }

            let pool = try bufferPool(for: request.configuration.size)
            dropReleasedRetiredPools()

            guard let buffer = pool.nextFreeBuffer() else {
                try interpretWindowEffects(model.reduce(.presentationBlockedByBuffer))
                return .waitingForBuffer
            }
            guard buffer.acquireForDrawing() else {
                try interpretWindowEffects(model.reduce(.presentationBlockedByBuffer))
                return .waitingForBuffer
            }

            do {
                try unsafe buffer.withUnsafeMutableBytes { bytes in
                    let frame = try unsafe SoftwareFrame(
                        width: buffer.width,
                        height: buffer.height,
                        stride: buffer.stride,
                        bytes: bytes
                    )
                    try draw(frame)
                }
            } catch {
                failActivePresentation(
                    generation: request.generation,
                    detail: String(describing: error)
                )
                buffer.markReleased()
                throw error
            }

            guard !model.isClosed else {
                try interpretWindowEffects(model.reduce(.transientStateReset))
                buffer.markReleased()
                return .skippedClosed
            }

            do {
                pendingFrameRegistration = try surface.requestFrame { [weak window = self] in
                    guard let window else { return }

                    window.handleFrameDone()
                }
            } catch {
                failActivePresentation(
                    generation: request.generation,
                    detail: String(describing: error)
                )
                buffer.markReleased()
                throw error
            }

            precondition(
                buffer.markBusy(commitGeneration: request.generation),
                "acquired drawing buffer must move to pending release"
            )
            surface.attach(buffer: buffer)
            surface.damageFullBuffer(width: buffer.width, height: buffer.height)
            surface.commit()

            try interpretWindowEffects(
                model.reduce(
                    .presentationSucceeded(
                        generation: request.generation,
                        bufferAvailable: redrawBufferAvailable
                    )
                )
            )
            return .presented
        } catch {
            failPresentationIfStillActive(generation: request.generation, error: error)
            throw error
        }
    }

    private func failPresentationIfStillActive(
        generation: UInt64,
        error: any Error
    ) {
        guard model.presentation == .drawing(generation: generation) else { return }

        failActivePresentation(
            generation: generation,
            detail: String(describing: error)
        )
    }

    private func failActivePresentation(
        generation: UInt64,
        detail: String
    ) {
        do {
            try interpretWindowEffects(
                model.reduce(.presentationFailed(generation: generation, .drawFailed(detail)))
            )
        } catch ClientError.window(id, .presentationFailed(.drawFailed(detail))) {
            // presentationFailed resets model state before reporting the presentation error.
        } catch {
            preconditionFailure("Unexpected presentation failure error: \(error)")
        }
    }

    private func monotonicMilliseconds() throws -> Int64 {
        var timestamp = timespec()
        guard unsafe clock_gettime(CLOCK_MONOTONIC, &timestamp) == 0 else {
            throw ClientError.windowCreationFailed("clock_gettime failed with errno \(errno)")
        }

        return Int64(timestamp.tv_sec) * 1_000 + Int64(timestamp.tv_nsec) / 1_000_000
    }

    private func resetTransientState() {
        do {
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
    private func handleFrameDone() {
        pendingFrameRegistration = nil
        dropReleasedRetiredPools()

        guard !model.isClosed else {
            resetTransientState()
            return
        }

        do {
            try interpretWindowEffects(
                model.reduce(.frameBecameReady(bufferAvailable: redrawBufferAvailable))
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
                model.reduce(.bufferBecameAvailable(bufferAvailable: redrawBufferAvailable))
            )
        } catch let error as ClientError {
            reportCallbackFailure(operation: .bufferReleased, error: error)
        } catch {
            reportCallbackFailure(operation: .bufferReleased, error: error)
        }
    }

    private func markNeedsRedraw() {
        guard !model.isClosed else {
            resetTransientState()
            return
        }

        do {
            try interpretWindowEffects(
                model.reduce(.contentInvalidated(bufferAvailable: redrawBufferAvailable))
            )
        } catch let error as ClientError {
            reportCallbackFailure(operation: .markNeedsRedraw, error: error)
        } catch {
            reportCallbackFailure(operation: .markNeedsRedraw, error: error)
        }
    }

    private var isDirty: Bool {
        model.redraw.isDirty
    }

    private var redrawBufferAvailable: Bool {
        buffers.map(\.hasFreeBuffers) ?? true
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func interpretWindowEffects(_ effects: [WindowEffect]) throws {
        for effect in effects {
            switch effect {
            case .ackConfigure(let serial):
                guard let activeXDGSurface = xdgSurface else {
                    throw ClientError.window(
                        id,
                        .invalidLifecycleTransition(
                            .invalidTransition(from: "missing xdg_surface", event: "ackConfigure")
                        )
                    )
                }
                activeXDGSurface.ackConfigure(serial: serial)
            case .publishCloseRequested:
                onCloseRequested?()
            case .publishClosed:
                onClosed?()
                onClosed = nil
            case .publishRedrawRequested:
                onRedrawRequested?()
            case .cancelFrameCallback:
                pendingFrameRegistration = nil
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
                surface.destroy()
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

        topLevelOwner?.cancel()
        decorationOwner?.cancel()
        decoration?.destroy()
        decoration = nil
        decorationOwner = nil

        topLevel?.destroy()
        topLevel = nil
        topLevelOwner = nil

        xdgSurfaceOwner?.cancel()
        xdgSurface?.destroy()
        xdgSurface = nil
        xdgSurfaceOwner = nil
    }
}

extension TopLevelWindow {
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

    package func markPublishedOnOwnerThread() {
        connection.preconditionIsOwnerThread()
        model.markPublished()
    }

    package func requestRedrawOnOwnerThread() throws {
        connection.preconditionIsOwnerThread()
        markNeedsRedraw()
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
