import WaylandRaw

private enum WindowLifecycleState: Equatable, CustomStringConvertible {
    case created
    case roleAssigned
    case waitingForInitialConfigure
    case configured(SurfaceConfigure)
    case mapped
    case closeRequested
    case destroyed

    var description: String {
        switch self {
        case .created:
            "created"
        case .roleAssigned:
            "roleAssigned"
        case .waitingForInitialConfigure:
            "waitingForInitialConfigure"
        case .configured(let configure):
            "configured(serial: \(configure.serial), "
                + "\(configure.size.width)x\(configure.size.height))"
        case .mapped:
            "mapped"
        case .closeRequested:
            "closeRequested"
        case .destroyed:
            "destroyed"
        }
    }
}

private enum RedrawOutcome: Equatable {
    case presented
    case skippedClosed
    case skippedPendingFrame
    case waitingForBuffer
}

public final class TopLevelWindow {
    public let id: WindowID

    private let connection: RawDisplayConnection
    private let configuration: WindowConfiguration
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
    private var needsRedrawStorage = false
    private var isClosedStorage = false
    package var onClose: (() -> Void)?

    public var isClosed: Bool {
        isClosedStorage
    }

    public var needsRedraw: Bool {
        needsRedrawStorage
    }

    public init(
        connection rawConnection: RawDisplayConnection,
        configuration windowConfiguration: WindowConfiguration = .init()
    ) throws {
        id = WindowID(rawValue: 0)
        connection = rawConnection
        configuration = windowConfiguration
        configureState = .init(fallbackSize: windowConfiguration.fallbackSize)

        let globals = try rawConnection.bindRequiredGlobals()
        surface = try globals.compositor.createSurface()
        try assignXDGRole(globals: globals)
    }

    package init(
        id windowID: WindowID,
        connection rawConnection: RawDisplayConnection,
        configuration windowConfiguration: WindowConfiguration = .init()
    ) throws {
        id = windowID
        connection = rawConnection
        configuration = windowConfiguration
        configureState = .init(fallbackSize: windowConfiguration.fallbackSize)

        let globals = try rawConnection.bindRequiredGlobals()
        surface = try globals.compositor.createSurface()
        try assignXDGRole(globals: globals)
    }

    public func show(_ draw: (SoftwareFrame) throws -> Void) throws {
        connection.preconditionIsOwnerThread()

        if currentConfigure == nil {
            _ = try waitForInitialConfigure()
        }

        _ = try drawAndPresent(draw)
    }

    public func show(
        timeoutMilliseconds: Int32,
        _ draw: (SoftwareFrame) throws -> Void
    ) throws {
        connection.preconditionIsOwnerThread()

        if currentConfigure == nil {
            _ = try waitForInitialConfigure(timeoutMilliseconds: timeoutMilliseconds)
        }

        _ = try drawAndPresent(draw)
    }

    public func redraw(_ draw: (SoftwareFrame) throws -> Void) throws {
        connection.preconditionIsOwnerThread()

        guard !isClosedStorage else { return }

        if let configure = try consumeLatestConfigureIfAvailable() {
            lifecycleState = .configured(configure)
        }

        _ = try drawAndPresent(draw)
    }

    public func close() {
        connection.preconditionIsOwnerThread()

        guard lifecycleState != .destroyed else { return }

        isClosedStorage = true
        pendingFrameRegistration = nil
        onClose?()
        onClose = nil

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

    package var surfaceID: RawObjectID {
        connection.preconditionIsOwnerThread()
        return surface.objectID
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

    private func waitForInitialConfigure() throws -> SurfaceConfigure {
        while !configureState.hasReceivedInitialConfigure, !isClosedStorage {
            try connection.pumpEvents(timeoutMilliseconds: 1_000)
            try configureState.throwPendingErrorIfAny()
        }

        guard let configure = try consumeLatestConfigureIfAvailable() else {
            throw ClientError.windowCreationFailed("missing initial configure")
        }

        return configure
    }

    private func waitForInitialConfigure(timeoutMilliseconds: Int32) throws -> SurfaceConfigure {
        var remainingMilliseconds = max(timeoutMilliseconds, 0)
        let pollMilliseconds: Int32 = 50

        while !configureState.hasReceivedInitialConfigure, !isClosedStorage {
            guard remainingMilliseconds > 0 else {
                throw ClientError.windowCreationFailed(
                    "timed out waiting for initial configure"
                )
            }

            let pumpTimeout = min(remainingMilliseconds, pollMilliseconds)
            try connection.pumpEvents(timeoutMilliseconds: pumpTimeout)
            try configureState.throwPendingErrorIfAny()
            remainingMilliseconds -= pumpTimeout
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
        )

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
        dropReleasedRetiredPools()

        guard !isClosedStorage else {
            needsRedrawStorage = false
            return
        }

        needsRedrawStorage = true
    }

    private func handleCloseRequested() {
        isClosedStorage = true
        pendingFrameRegistration = nil
        needsRedrawStorage = false
        lifecycleState = .closeRequested
    }

    private func drawAndPresent(_ draw: (SoftwareFrame) throws -> Void) throws -> RedrawOutcome {
        guard !isClosedStorage else { return .skippedClosed }
        guard pendingFrameRegistration == nil else { return .skippedPendingFrame }
        guard let configure = currentConfigure else {
            throw ClientError.invalidWindowState(lifecycleState.description)
        }

        let pool = try bufferPool(for: configure.size)
        dropReleasedRetiredPools()

        guard let buffer = pool.nextFreeBuffer() else {
            needsRedrawStorage = true
            return .waitingForBuffer
        }

        let frame = SoftwareFrame(
            width: buffer.width,
            height: buffer.height,
            stride: buffer.stride,
            bytes: buffer.bytes
        )

        try draw(frame)

        pendingFrameRegistration = try surface.requestFrame { [weak window = self] in
            guard let window else { return }

            window.handleFrameDone()
        }

        buffer.markBusy()
        surface.attach(buffer: buffer)
        surface.damageFullBuffer(width: buffer.width, height: buffer.height)
        surface.commit()

        lifecycleState = .mapped
        needsRedrawStorage = false
        return .presented
    }
}
