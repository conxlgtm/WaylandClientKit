import Glibc
import WaylandRaw

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
    private var xdgSurfaceOwner: XDGSurfaceOwner?
    private var topLevelOwner: XDGTopLevelOwner?
    private var buffers: RawSharedMemoryPool?
    private var retiredBufferPools: [RawSharedMemoryPool] = []
    private var pendingFrameRegistration: FrameCallbackRegistration?
    private var lifecycleState = WindowLifecycleState.created
    private var currentConfigure: SurfaceConfigure?
    private var redrawState = WindowRedrawState()
    private var isClosedStorage = false
    private var isPresentingFrame = false
    package var onClose: (() -> Void)?
    package var onCloseRequested: (() -> Void)?
    package var onRedrawRequested: (() -> Void)?

    package init(
        id windowID: WindowID,
        connection rawConnection: RawDisplayConnection,
        configuration windowConfiguration: WindowConfiguration = .init(),
        initialConfigurePump pumpEvents: ((Int32) throws -> Void)? = nil
    ) throws {
        try windowConfiguration.validate()

        id = windowID
        connection = rawConnection
        configuration = windowConfiguration
        initialConfigurePump =
            pumpEvents
            ?? { timeoutMilliseconds in
                try rawConnection.pumpEvents(timeoutMilliseconds: timeoutMilliseconds)
            }
        configureState = .init(
            fallbackSize: TopLevelSize(
                width: windowConfiguration.initialWidth,
                height: windowConfiguration.initialHeight
            )
        )

        let globals = try rawConnection.bindRequiredGlobals()
        surface = try globals.compositor.createSurface()
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

        newTopLevel.setTitle(configuration.title)
        newTopLevel.setAppID(configuration.appID)

        let newXDGSurfaceOwner = XDGSurfaceOwner(configureState: configureState)
        try newXDGSurfaceOwner.install(on: newXDGSurface)

        let newTopLevelOwner = XDGTopLevelOwner(configureState: configureState)
        try newTopLevelOwner.install(on: newTopLevel) { [weak window = self] in
            guard let window else { return }

            window.handleCloseRequested()
        }

        xdgSurface = newXDGSurface
        topLevel = newTopLevel
        xdgSurfaceOwner = newXDGSurfaceOwner
        topLevelOwner = newTopLevelOwner

        lifecycleState = .roleAssigned
        surface.commit()
        lifecycleState = .waitingForInitialConfigure
    }

    private func waitForInitialConfigure(timeoutMilliseconds: Int32) throws -> SurfaceConfigure {
        guard timeoutMilliseconds >= 0 else {
            throw ClientError.invalidWindowConfiguration(
                "timeoutMilliseconds must be greater than or equal to zero"
            )
        }

        let timeout = Int64(max(timeoutMilliseconds, 0))
        let deadline = try monotonicMilliseconds() + timeout
        let pollMilliseconds: Int32 = 50

        while !configureState.hasReceivedInitialConfigure, !isClosedStorage {
            let remainingMilliseconds = deadline - (try monotonicMilliseconds())
            guard remainingMilliseconds > 0 else {
                throw ClientError.windowCreationFailed(
                    "timed out waiting for initial configure"
                )
            }

            let boundedRemaining = Int32(min(remainingMilliseconds, Int64(Int32.max)))
            let pumpTimeout = min(boundedRemaining, pollMilliseconds)
            try initialConfigurePump(pumpTimeout)
            try configureState.throwPendingErrorIfAny()
        }

        guard let configure = try consumeLatestConfigureIfAvailable() else {
            throw ClientError.windowCreationFailed("missing initial configure")
        }

        return configure
    }

    private func consumeLatestConfigureIfAvailable() throws -> SurfaceConfigure? {
        try configureState.throwPendingErrorIfAny()

        guard let configure = configureState.consumeLatestConfigure() else {
            return nil
        }

        guard let activeXDGSurface = xdgSurface else {
            throw ClientError.invalidWindowState("xdg_surface missing")
        }

        activeXDGSurface.ackConfigure(serial: configure.serial)
        currentConfigure = configure
        lifecycleState = .configured(configure)
        return configure
    }

    private func bufferPool(for size: TopLevelSize) throws -> RawSharedMemoryPool {
        if let buffers, buffers.size == size {
            return buffers
        }

        if let buffers, buffers.hasBusyBuffers {
            retiredBufferPools.append(buffers)
        }

        guard let globals = connection.boundGlobals else {
            throw ClientError.windowCreationFailed("required globals are not bound")
        }

        let newPool = try globals.sharedMemory.createPool(
            width: size.width,
            height: size.height,
            bufferCount: configuration.bufferCount
        ) { [weak window = self] in
            window?.handleBufferReleased()
        }

        buffers = newPool
        return newPool
    }

    private func dropReleasedRetiredPools() {
        retiredBufferPools.removeAll { pool in
            !pool.hasBusyBuffers
        }
    }

    private func handleFrameDone() {
        pendingFrameRegistration = nil
        redrawState.markFrameReady()
        dropReleasedRetiredPools()

        guard !isClosedStorage else {
            redrawState.resetTransientState()
            return
        }

        maybePublishRedrawRequested()
    }

    private func handleBufferReleased() {
        connection.preconditionIsOwnerThread()
        dropReleasedRetiredPools()

        guard !isClosedStorage, redrawState.isWaitingForBuffer else { return }
        maybePublishRedrawRequested()
    }

    private func handleCloseRequested() {
        guard !isClosedStorage, lifecycleState != .closeRequested else { return }

        lifecycleState = .closeRequested
        onCloseRequested?()
    }

    private func markNeedsRedraw() {
        guard !isClosedStorage else {
            redrawState.resetTransientState()
            return
        }

        redrawState.markContentDirty()
        maybePublishRedrawRequested()
    }

    private var isDirty: Bool {
        redrawState.isDirty
    }

    private func maybePublishRedrawRequested() {
        guard !isClosedStorage else { return }
        let bufferUnavailable = buffers.map { !$0.hasFreeBuffers } ?? false
        guard redrawState.shouldPublishRedrawRequest(bufferUnavailable: bufferUnavailable) else {
            return
        }

        onRedrawRequested?()
    }

    private func drawAndPresent(
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> RedrawOutcome {
        guard !isClosedStorage else { return .skippedClosed }
        redrawState.beginDrawAttempt()
        guard pendingFrameRegistration == nil else { return .skippedPendingFrame }
        guard !isPresentingFrame else {
            throw ClientError.invalidWindowState("cannot draw while another draw is active")
        }
        guard let configure = currentConfigure else {
            throw ClientError.invalidWindowState(lifecycleState.description)
        }

        isPresentingFrame = true
        defer { isPresentingFrame = false }

        let pool = try bufferPool(for: configure.size)
        dropReleasedRetiredPools()

        guard let buffer = pool.nextFreeBuffer() else {
            redrawState.markWaitingForBuffer()
            return .waitingForBuffer
        }

        let generationDrawn = redrawState.generationForCurrentDraw()
        let frame = try unsafe SoftwareFrame(
            width: buffer.width,
            height: buffer.height,
            stride: buffer.stride,
            bytes: buffer.bytes
        )

        try draw(frame)

        guard !isClosedStorage else { return .skippedClosed }

        pendingFrameRegistration = try surface.requestFrame { [weak window = self] in
            guard let window else { return }

            window.handleFrameDone()
        }
        redrawState.markFramePending()

        buffer.markBusy()
        surface.attach(buffer: buffer)
        surface.damageFullBuffer(width: buffer.width, height: buffer.height)
        surface.commit()

        lifecycleState = .mapped
        redrawState.markPresented(generation: generationDrawn)
        return .presented
    }

    private func monotonicMilliseconds() throws -> Int64 {
        var timestamp = timespec()
        guard unsafe clock_gettime(CLOCK_MONOTONIC, &timestamp) == 0 else {
            throw ClientError.windowCreationFailed("clock_gettime failed with errno \(errno)")
        }

        return Int64(timestamp.tv_sec) * 1_000 + Int64(timestamp.tv_nsec) / 1_000_000
    }
}

extension TopLevelWindow {
    package var isClosedOnOwnerThread: Bool {
        connection.preconditionIsOwnerThread()
        return isClosedStorage
    }

    package var needsRedrawOnOwnerThread: Bool {
        connection.preconditionIsOwnerThread()
        return isDirty
    }

    package func requestRedrawOnOwnerThread() {
        connection.preconditionIsOwnerThread()
        markNeedsRedraw()
    }

    package func showOnOwnerThread(
        timeoutMilliseconds: Int32 = defaultConfigureTimeoutMS,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        connection.preconditionIsOwnerThread()

        if currentConfigure == nil {
            _ = try waitForInitialConfigure(timeoutMilliseconds: timeoutMilliseconds)
        }

        _ = try drawAndPresent(draw)
    }

    package func redrawOnOwnerThread(
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        connection.preconditionIsOwnerThread()

        guard !isClosedStorage else { return }

        if let configure = try consumeLatestConfigureIfAvailable() {
            lifecycleState = .configured(configure)
        }

        _ = try drawAndPresent(draw)
    }

    package func closeOnOwnerThread() {
        connection.preconditionIsOwnerThread()

        guard lifecycleState != .destroyed else { return }

        isClosedStorage = true
        pendingFrameRegistration = nil
        redrawState.resetTransientState()
        onClose?()
        onClose = nil
        onCloseRequested = nil

        topLevel?.destroy()
        topLevel = nil
        topLevelOwner = nil

        xdgSurface?.destroy()
        xdgSurface = nil
        xdgSurfaceOwner = nil

        buffers = nil
        retiredBufferPools.removeAll()
        surface.destroy()
        lifecycleState = .destroyed
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
