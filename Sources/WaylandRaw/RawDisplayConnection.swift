import CWaylandClientSystem
import CWaylandProtocols
import Glibc

public final class RawDisplayConnection {
    public static let defaultDiscoveryTimeoutMS: Int32 = 1_000

    let display: RawDisplay
    let eventQueue: RawEventQueue
    package let invariantFailureSink: RawInvariantFailureSink
    let proxyAdoption: RawProxyAdoptionContext
    let registry: RawRegistry
    public private(set) var boundGlobals: BoundGlobals?

    private let registryState: RegistryState
    private let registryListenerOwner: RegistryListenerOwner
    private let inputEventQueue: RawInputEventQueue
    private let threadAffinity = ThreadAffinity()

    private init(
        display rawDisplay: RawDisplay,
        eventQueue rawEventQueue: RawEventQueue,
        invariantFailureSink rawInvariantFailureSink: RawInvariantFailureSink,
        registry rawRegistry: RawRegistry,
        registryState rawRegistryState: RegistryState,
        registryListenerOwner rawRegistryListenerOwner: RegistryListenerOwner,
        inputEventQueue rawInputEventQueue: RawInputEventQueue
    ) {
        display = rawDisplay
        eventQueue = rawEventQueue
        invariantFailureSink = rawInvariantFailureSink
        proxyAdoption = RawProxyAdoptionContext(
            eventQueue: rawEventQueue,
            invariantFailureSink: rawInvariantFailureSink
        )
        registry = rawRegistry
        registryState = rawRegistryState
        registryListenerOwner = rawRegistryListenerOwner
        inputEventQueue = rawInputEventQueue
        registryListenerOwner.onGlobalRemoved = { [weak connection = self] name in
            connection?.boundGlobals?.seatRegistry.removeSeat(globalName: name)
        }
    }

    package func preconditionIsOwnerThread(
        _ operation: StaticString = #function,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        threadAffinity.preconditionIsOwnerThread(operation, file: file, line: line)
    }

    @available(
        *,
        noasync,
        message: "Use a synchronous owner-thread Wayland loop."
    )
    public static func connect() throws -> RawDisplayConnection {
        guard let displayPointer = wl_display_connect(nil) else {
            throw RuntimeError.connectionFailed
        }

        let rawDisplay = RawDisplay(
            opaquePointer: displayPointer,
            version: 1,
            ownership: .connectionLifetime
        )

        guard let eventQueuePointer = swl_display_create_event_queue(displayPointer) else {
            wl_display_disconnect(displayPointer)
            throw RuntimeError.eventQueueCreationFailed
        }
        let rawEventQueue = RawEventQueue(opaquePointer: eventQueuePointer)

        guard let wrappedDisplay = swl_display_create_wrapper(displayPointer) else {
            rawEventQueue.destroy()
            wl_display_disconnect(displayPointer)
            throw RuntimeError.displayWrapperCreationFailed
        }
        swl_display_wrapper_set_queue(wrappedDisplay, eventQueuePointer)

        guard let registryPointer = swl_display_get_registry(wrappedDisplay) else {
            swl_display_wrapper_destroy(wrappedDisplay)
            rawEventQueue.destroy()
            wl_display_disconnect(displayPointer)
            throw RuntimeError.registryCreationFailed
        }
        swl_display_wrapper_destroy(wrappedDisplay)

        let state = RegistryState()
        let invariantFailureSink = RawInvariantFailureSink()
        let listenerOwner = RegistryListenerOwner(
            state: state,
            invariantFailureSink: invariantFailureSink
        )
        let inputEventQueue = RawInputEventQueue()

        let rawRegistry = RawRegistry(
            opaquePointer: rawEventQueue.assertedProxy(
                registryPointer,
                interface: "wl_registry"
            ),
            version: 1,
            ownership: .connectionLifetime
        )

        do {
            try listenerOwner.install(on: registryPointer)
        } catch {
            swl_registry_destroy(registryPointer)
            rawEventQueue.destroy()
            wl_display_disconnect(displayPointer)
            throw error
        }

        return RawDisplayConnection(
            display: rawDisplay,
            eventQueue: rawEventQueue,
            invariantFailureSink: invariantFailureSink,
            registry: rawRegistry,
            registryState: state,
            registryListenerOwner: listenerOwner,
            inputEventQueue: inputEventQueue
        )
    }

    @available(
        *,
        noasync,
        message: "Read globals from the owner-thread Wayland loop."
    )
    public var globals: [RawGlobalAdvertisement] {
        preconditionIsOwnerThread()
        return registryState.snapshot
    }

    @available(
        *,
        noasync,
        message: "Read globals from the owner-thread Wayland loop."
    )
    public func global(named interfaceName: String) -> RawGlobalAdvertisement? {
        preconditionIsOwnerThread()
        return registryState.firstGlobal(named: interfaceName)
    }

    @available(
        *,
        noasync,
        message: "Pump events from the owner-thread Wayland loop."
    )
    public func pumpEvents(timeoutMilliseconds: Int32 = -1) throws {
        preconditionIsOwnerThread()

        try QueueEventLoop.pumpOnce(
            display: display.opaquePointer,
            eventQueue: eventQueue.opaquePointer,
            timeoutMilliseconds: timeoutMilliseconds
        )
    }

    @available(
        *,
        noasync,
        message: "Drain input from the owner-thread Wayland loop."
    )
    public func drainInputEvents() -> [RawInputEvent] {
        preconditionIsOwnerThread()
        return inputEventQueue.drain()
    }

    @available(
        *,
        noasync,
        message: "Run event loops from the owner-thread Wayland loop."
    )
    public func runEventLoop(while shouldContinue: () -> Bool) throws {
        preconditionIsOwnerThread()

        try QueueEventLoop.run(
            display: display.opaquePointer,
            eventQueue: eventQueue.opaquePointer,
            shouldContinue: shouldContinue
        )
    }

    deinit {
        preconditionIsOwnerThread()
        boundGlobals?.destroy()
        registryListenerOwner.cancel()
        swl_registry_destroy(registry.opaquePointer)
        eventQueue.destroy()
        wl_display_disconnect(display.opaquePointer)
    }

    package func setInvariantFailureReporter(_ reporter: (any RawInvariantFailureReporter)?) {
        preconditionIsOwnerThread()
        invariantFailureSink.reporter = reporter
    }
}

extension RawDisplayConnection {
    private struct RequiredGlobalBindingSet {
        let compositor: RawGlobalAdvertisement
        let compositorVersion: RawVersion
        let sharedMemory: RawGlobalAdvertisement
        let sharedMemoryVersion: RawVersion
        let xdgWMBase: RawGlobalAdvertisement
        let xdgWMBaseVersion: RawVersion
    }

    @discardableResult
    @available(
        *,
        noasync,
        message: "Bind globals from the owner-thread Wayland loop."
    )
    public func bindRequiredGlobals() throws -> BoundGlobals {
        preconditionIsOwnerThread()

        if let boundGlobals {
            return boundGlobals
        }

        let reg = registry.opaquePointer
        let bindingSet = try requiredGlobalBindingSet()
        let compositorWrapper = try bindCompositor(
            registry: reg,
            global: bindingSet.compositor,
            version: bindingSet.compositorVersion
        )
        let shm = try bindSharedMemory(
            registry: reg,
            global: bindingSet.sharedMemory,
            version: bindingSet.sharedMemoryVersion,
            compositor: compositorWrapper
        )
        let xdgWmBase = try bindXDGWMBase(
            registry: reg,
            global: bindingSet.xdgWMBase,
            version: bindingSet.xdgWMBaseVersion,
            compositor: compositorWrapper,
            shm: shm
        )
        let seatRegistry = try bindSeatRegistry(
            registry: reg,
            xdgWMBase: xdgWmBase,
            sharedMemory: shm,
            compositor: compositorWrapper
        )

        let bound = BoundGlobals(
            compositor: compositorWrapper,
            sharedMemory: shm,
            xdgWMBase: xdgWmBase,
            seatRegistry: seatRegistry
        )

        boundGlobals = bound
        return bound
    }

    private func requiredGlobalBindingSet() throws -> RequiredGlobalBindingSet {
        let compositor = try requiredGlobal(named: "wl_compositor")
        let sharedMemory = try requiredGlobal(named: "wl_shm")
        let xdgWMBase = try requiredGlobal(named: "xdg_wm_base")

        return .init(
            compositor: compositor,
            compositorVersion: compositor.negotiatedVersion(
                supportedByClient: SupportedVersions.wlCompositor
            ),
            sharedMemory: sharedMemory,
            sharedMemoryVersion: sharedMemory.negotiatedVersion(
                supportedByClient: SupportedVersions.wlShm
            ),
            xdgWMBase: xdgWMBase,
            xdgWMBaseVersion: xdgWMBase.negotiatedVersion(
                supportedByClient: SupportedVersions.xdgWmBase
            )
        )
    }

    private func requiredGlobal(named interfaceName: String) throws -> RawGlobalAdvertisement {
        guard let global = registryState.firstGlobal(named: interfaceName) else {
            throw RuntimeError.missingRequiredGlobal(interfaceName)
        }

        return global
    }

    private func bindSharedMemory(
        registry reg: OpaquePointer,
        global shmGlobal: RawGlobalAdvertisement,
        version shmVersion: RawVersion,
        compositor: RawCompositor
    ) throws -> RawSharedMemory {
        guard let shm = swl_registry_bind_wl_shm(reg, shmGlobal.name, shmVersion.value) else {
            compositor.destroy()
            throw RuntimeError.bindFailed("wl_shm")
        }

        return .init(pointer: shm, version: shmVersion, proxyAdoption: proxyAdoption)
    }

    private func bindCompositor(
        registry reg: OpaquePointer,
        global compositorGlobal: RawGlobalAdvertisement,
        version compositorVersion: RawVersion
    ) throws -> RawCompositor {
        guard
            let compositor = swl_registry_bind_wl_compositor(
                reg,
                compositorGlobal.name,
                compositorVersion.value
            )
        else {
            throw RuntimeError.bindFailed("wl_compositor")
        }

        return .init(
            pointer: compositor,
            version: compositorVersion,
            proxyAdoption: proxyAdoption
        )
    }

    private func bindXDGWMBase(
        registry reg: OpaquePointer,
        global xdgGlobal: RawGlobalAdvertisement,
        version xdgVersion: RawVersion,
        compositor: RawCompositor,
        shm: RawSharedMemory
    ) throws -> RawXDGWMBase {
        guard
            let xdgWmBase = swl_registry_bind_xdg_wm_base(
                reg,
                xdgGlobal.name,
                xdgVersion.value
            )
        else {
            shm.destroy()
            compositor.destroy()
            throw RuntimeError.bindFailed("xdg_wm_base")
        }

        do {
            return try .init(
                pointer: xdgWmBase,
                version: xdgVersion,
                proxyAdoption: proxyAdoption
            )
        } catch {
            swl_xdg_wm_base_destroy(xdgWmBase)
            shm.destroy()
            compositor.destroy()
            throw error
        }
    }

    private func bindSeatRegistry(
        registry reg: OpaquePointer,
        xdgWMBase: RawXDGWMBase,
        sharedMemory shm: RawSharedMemory,
        compositor: RawCompositor
    ) throws -> SeatRegistry {
        let seatRegistry = SeatRegistry(
            registry: reg,
            eventSink: inputEventQueue,
            proxyAdoption: proxyAdoption,
            invariantFailureSink: invariantFailureSink
        )

        do {
            try seatRegistry.bindSeats(from: registryState.snapshot)
            return seatRegistry
        } catch {
            xdgWMBase.destroy()
            shm.destroy()
            compositor.destroy()
            throw error
        }
    }
}

extension RawDisplayConnection {
    package var eventLoopFileDescriptor: CInt {
        preconditionIsOwnerThread()
        return EventLoop.fileDescriptor(display: display.opaquePointer)
    }

    package func dispatchPendingEvents() throws -> Int32 {
        preconditionIsOwnerThread()
        return try QueueEventLoop.dispatchPending(
            display: display.opaquePointer,
            eventQueue: eventQueue.opaquePointer
        )
    }

    package func prepareReadEvents() throws -> Bool {
        preconditionIsOwnerThread()
        return try QueueEventLoop.prepareRead(
            display: display.opaquePointer,
            eventQueue: eventQueue.opaquePointer
        )
    }

    package func flushForExternalEventLoop() throws -> Bool {
        preconditionIsOwnerThread()
        return try EventLoop.flushForExternalPoll(display: display.opaquePointer)
    }

    package func readEvents() throws {
        preconditionIsOwnerThread()
        try EventLoop.readEvents(display: display.opaquePointer)
    }

    package func cancelReadEvents() {
        preconditionIsOwnerThread()
        EventLoop.cancelRead(display: display.opaquePointer)
    }

    package func pumpEvents(
        timeoutMilliseconds: Int32,
        wakeFileDescriptor: CInt,
        drainWakeFileDescriptor: @escaping () -> Void
    ) throws {
        preconditionIsOwnerThread()

        try QueueEventLoop.pumpOnce(
            display: display.opaquePointer,
            eventQueue: eventQueue.opaquePointer,
            timeoutMilliseconds: timeoutMilliseconds,
            wakeFileDescriptor: wakeFileDescriptor,
            drainWakeFileDescriptor: drainWakeFileDescriptor
        )
    }

    @available(
        *,
        noasync,
        message: "Run discovery from the owner-thread Wayland loop."
    )
    public func completeInitialDiscovery(
        timeoutMilliseconds: Int32 = defaultDiscoveryTimeoutMS
    ) throws {
        preconditionIsOwnerThread()
        guard timeoutMilliseconds >= 0 else {
            throw RuntimeError.operationTimedOut(
                "initial discovery timeout must be greater than or equal to zero"
            )
        }

        let wrappedDisplay = try createDisplayWrapperOnEventQueue()
        guard let syncCallback = swl_display_sync(wrappedDisplay) else {
            swl_display_wrapper_destroy(wrappedDisplay)
            throw RuntimeError.displaySyncRequestFailed
        }
        swl_display_wrapper_destroy(wrappedDisplay)
        _ = proxyAdoption.adopt(syncCallback, interface: "wl_callback")

        var didFire = false
        let deadline = try rawMonotonicMilliseconds() + Int64(timeoutMilliseconds)
        let registration = try FrameCallbackRegistration(
            pointer: syncCallback,
            onDone: { didFire = true },
            invariantFailureSink: invariantFailureSink
        )

        try withExtendedLifetime(registration) {
            while !didFire {
                let remainingMilliseconds = deadline - (try rawMonotonicMilliseconds())
                guard remainingMilliseconds > 0 else {
                    throw RuntimeError.operationTimedOut("timed out waiting for initial globals")
                }

                let boundedRemaining = Int32(min(remainingMilliseconds, Int64(Int32.max)))
                try QueueEventLoop.pumpOnce(
                    display: display.opaquePointer,
                    eventQueue: eventQueue.opaquePointer,
                    timeoutMilliseconds: min(boundedRemaining, 50)
                )
            }
        }
    }

    private func createDisplayWrapperOnEventQueue() throws -> OpaquePointer {
        guard let wrappedDisplay = swl_display_create_wrapper(display.opaquePointer) else {
            throw RuntimeError.displayWrapperCreationFailed
        }

        swl_display_wrapper_set_queue(wrappedDisplay, eventQueue.opaquePointer)
        return wrappedDisplay
    }
}
