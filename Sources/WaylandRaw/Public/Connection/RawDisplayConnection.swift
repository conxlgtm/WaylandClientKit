import CWaylandClientSystem
import CWaylandProtocols
import Glibc

// swiftlint:disable file_length

@safe
private struct RegistryResources {
    let registry: RawRegistry
    let state: RegistryState
    let listenerOwner: RegistryListenerOwner
    let inputEventQueue: RawInputEventQueue
}

@safe
package final class RawDisplayConnection {  // swiftlint:disable:this type_body_length
    package static let defaultDiscoveryTimeoutMS: Int32 = 1_000

    let display: RawDisplay
    let eventQueue: RawEventQueue
    package let invariantFailureSink: RawInvariantFailureSink
    let proxyAdoption: RawProxyAdoptionContext
    let registry: RawRegistry
    package private(set) var boundGlobals: BoundGlobals?
    package var inputEventSink: any RawInputEventSink {
        inputEventQueue
    }

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
        registryListenerOwner.onGlobalAdvertised = { [weak connection = self] global in
            guard let connection, let boundGlobals = connection.boundGlobals else { return }

            do {
                if global.interfaceName == "wl_seat",
                    let seat = try boundGlobals.seatRegistry.bindSeat(
                        globalName: global.name,
                        advertisedVersion: global.advertisedVersion
                    )
                {
                    boundGlobals.tabletSeatRegistry?.bindTabletSeat(for: seat)
                }
                try boundGlobals.outputRegistry.bindAdvertisedOutput(global)
            } catch {
                connection.invariantFailureSink.reportFatalRawInvariantFailure(
                    .globalBindingFailed(
                        interface: global.interfaceName,
                        name: global.name,
                        reason: String(describing: error)
                    )
                )
            }
        }
        registryListenerOwner.onGlobalRemoved = { [weak connection = self] global in
            connection?.boundGlobals?.tabletSeatRegistry?.removeSeat(globalName: global.name)
            connection?.boundGlobals?.seatRegistry.removeSeat(globalName: global.name)
            connection?.boundGlobals?.outputRegistry.removeOutput(globalName: global.name)
            connection?.boundGlobals?.invalidateOptionalGlobal(named: global.interfaceName)
        }
    }

    package func preconditionIsOwnerThread(
        _ operation: StaticString = #function,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        threadAffinity.preconditionIsOwnerThread(operation, file: file, line: line)
    }

    @available(*, noasync, message: "Use a synchronous owner-thread Wayland loop.")
    package static func connect() throws -> RawDisplayConnection {
        try connect(
            invariantFailureSink: RawInvariantFailureSink(),
            inputQueueConfiguration: RawInputQueueConfiguration()
        )
    }

    @available(*, noasync, message: "Use a synchronous owner-thread Wayland loop.")
    package static func connect(
        invariantFailureSink: RawInvariantFailureSink,
        inputQueueConfiguration: RawInputQueueConfiguration
    ) throws -> RawDisplayConnection {
        errno = 0
        guard let displayPointer = unsafe wl_display_connect(nil) else {
            let savedErrno = errno
            guard savedErrno <= 0 else {
                throw RuntimeError.systemError(errno: savedErrno, operation: .connectDisplay)
            }

            throw RuntimeError.connectionFailed
        }

        let rawDisplay = RawDisplay(
            opaquePointer: displayPointer,
            version: 1,
            ownership: .connectionLifetime
        )

        guard let eventQueuePointer = unsafe swl_display_create_event_queue(displayPointer) else {
            unsafe wl_display_disconnect(displayPointer)
            throw RuntimeError.eventQueueCreationFailed
        }
        let rawEventQueue = RawEventQueue(opaquePointer: eventQueuePointer)

        guard let wrappedDisplay = unsafe swl_display_create_wrapper(displayPointer) else {
            rawEventQueue.destroy()
            unsafe wl_display_disconnect(displayPointer)
            throw RuntimeError.displayWrapperCreationFailed
        }
        unsafe swl_display_wrapper_set_queue(wrappedDisplay, eventQueuePointer)

        guard let registryPointer = unsafe swl_display_get_registry(wrappedDisplay) else {
            unsafe swl_display_wrapper_destroy(wrappedDisplay)
            rawEventQueue.destroy()
            unsafe wl_display_disconnect(displayPointer)
            throw RuntimeError.registryCreationFailed
        }
        unsafe swl_display_wrapper_destroy(wrappedDisplay)

        let registryResources = try createRegistryResources(
            displayPointer: displayPointer,
            eventQueue: rawEventQueue,
            registryPointer: registryPointer,
            invariantFailureSink: invariantFailureSink,
            inputQueueConfiguration: inputQueueConfiguration
        )

        return RawDisplayConnection(
            display: rawDisplay,
            eventQueue: rawEventQueue,
            invariantFailureSink: invariantFailureSink,
            registry: registryResources.registry,
            registryState: registryResources.state,
            registryListenerOwner: registryResources.listenerOwner,
            inputEventQueue: registryResources.inputEventQueue
        )
    }

    @safe
    private static func createRegistryResources(
        displayPointer: OpaquePointer,
        eventQueue: RawEventQueue,
        registryPointer: OpaquePointer,
        invariantFailureSink: RawInvariantFailureSink,
        inputQueueConfiguration: RawInputQueueConfiguration
    ) throws -> RegistryResources {
        let state = RegistryState()
        let listenerOwner = RegistryListenerOwner(
            state: state,
            invariantFailureSink: invariantFailureSink
        )
        let inputEventQueue = RawInputEventQueue(configuration: inputQueueConfiguration)

        do {
            let adoptedRegistryPointer = try eventQueue.assertedProxy(
                registryPointer,
                interface: "wl_registry",
                invariantFailureSink: invariantFailureSink
            )
            try unsafe listenerOwner.install(on: registryPointer)
            let registry = unsafe RawRegistry(
                opaquePointer: adoptedRegistryPointer,
                version: 1,
                ownership: .connectionLifetime
            )
            return RegistryResources(
                registry: registry,
                state: state,
                listenerOwner: listenerOwner,
                inputEventQueue: inputEventQueue
            )
        } catch {
            unsafe swl_registry_destroy(registryPointer)
            eventQueue.destroy()
            unsafe wl_display_disconnect(displayPointer)
            throw error
        }
    }

    @available(
        *,
        noasync,
        message: "Read globals from the owner-thread Wayland loop."
    )
    package var globals: [RawGlobalAdvertisement] {
        preconditionIsOwnerThread()
        return registryState.snapshot
    }

    @available(
        *,
        noasync,
        message: "Read globals from the owner-thread Wayland loop."
    )
    package func global(named interfaceName: String) -> RawGlobalAdvertisement? {
        preconditionIsOwnerThread()
        return registryState.firstGlobal(named: interfaceName)
    }

    @available(
        *,
        noasync,
        message: "Pump events from the owner-thread Wayland loop."
    )
    package func pumpEvents(timeoutMilliseconds: Int32 = -1) throws {
        preconditionIsOwnerThread()

        try unsafe QueueEventLoop.pumpOnce(
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
    package func drainInputEvents() -> [RawInputEvent] {
        preconditionIsOwnerThread()
        return inputEventQueue.drain()
    }

    @available(
        *,
        noasync,
        message: "Read outputs from the owner-thread Wayland loop."
    )
    package func outputSnapshots() throws -> [RawOutputSnapshot] {
        preconditionIsOwnerThread()
        return try bindRequiredGlobals().outputRegistry.snapshots
    }

    @available(
        *,
        noasync,
        message: "Drain outputs from the owner-thread Wayland loop."
    )
    package func drainOutputEvents() -> [RawOutputEvent] {
        preconditionIsOwnerThread()
        return boundGlobals?.outputRegistry.drainEvents() ?? []
    }

    @available(
        *,
        noasync,
        message: "Run event loops from the owner-thread Wayland loop."
    )
    package func runEventLoop(while shouldContinue: () -> Bool) throws {
        preconditionIsOwnerThread()

        try unsafe QueueEventLoop.run(
            display: display.opaquePointer,
            eventQueue: eventQueue.opaquePointer,
            shouldContinue: shouldContinue
        )
    }

    deinit {
        preconditionIsOwnerThread()
        boundGlobals?.destroy()
        registryListenerOwner.cancel()
        unsafe swl_registry_destroy(registry.opaquePointer)
        eventQueue.destroy()
        unsafe wl_display_disconnect(display.opaquePointer)
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

    private struct OptionalGlobalBindingSet {
        let extensions: OptionalGlobals
        let outputRegistry: OutputRegistry
        let tabletSeatRegistry: TabletSeatRegistry?
    }

    @discardableResult
    @available(
        *,
        noasync,
        message: "Bind globals from the owner-thread Wayland loop."
    )
    package func bindRequiredGlobals() throws -> BoundGlobals {
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
        let optionalBindingSet = try unsafe bindOptionalGlobalsAndOutputs(
            registry: reg,
            xdgWMBase: xdgWmBase,
            sharedMemory: shm,
            compositor: compositorWrapper,
            seatRegistry: seatRegistry
        )

        let bound = BoundGlobals(
            compositor: compositorWrapper,
            sharedMemory: shm,
            xdgWMBase: xdgWmBase,
            seatRegistry: seatRegistry,
            outputRegistry: optionalBindingSet.outputRegistry,
            extensions: optionalBindingSet.extensions,
            tabletSeatRegistry: optionalBindingSet.tabletSeatRegistry
        )

        boundGlobals = bound
        return bound
    }

    private func bindOptionalGlobalsAndOutputs(
        registry reg: OpaquePointer,
        xdgWMBase: RawXDGWMBase,
        sharedMemory shm: RawSharedMemory,
        compositor: RawCompositor,
        seatRegistry: SeatRegistry
    ) throws -> OptionalGlobalBindingSet {
        let extensions: OptionalGlobals
        do {
            extensions = try bindOptionalGlobals(registry: reg)
        } catch {
            seatRegistry.destroy()
            xdgWMBase.destroy()
            shm.destroy()
            compositor.destroy()
            throw error
        }

        var tabletSeatRegistry: TabletSeatRegistry?
        do {
            tabletSeatRegistry = bindTabletSeatRegistryIfPresent(
                extensions: extensions,
                seatRegistry: seatRegistry
            )
            let outputRegistry = try bindOutputRegistry(
                registry: reg,
                extensions: extensions
            )
            return OptionalGlobalBindingSet(
                extensions: extensions,
                outputRegistry: outputRegistry,
                tabletSeatRegistry: tabletSeatRegistry
            )
        } catch {
            tabletSeatRegistry?.destroy()
            extensions.destroy()
            seatRegistry.destroy()
            xdgWMBase.destroy()
            shm.destroy()
            compositor.destroy()
            throw error
        }
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

    package func optionalGlobal(named interfaceName: String) -> RawGlobalAdvertisement? {
        registryState.startupGlobal(named: interfaceName)
    }

    package func freezeStartupGlobals() {
        registryState.freezeStartupGlobals()
    }

    @safe
    private func bindSharedMemory(
        registry reg: OpaquePointer,
        global shmGlobal: RawGlobalAdvertisement,
        version shmVersion: RawVersion,
        compositor: RawCompositor
    ) throws -> RawSharedMemory {
        guard let shm = unsafe swl_registry_bind_wl_shm(reg, shmGlobal.name, shmVersion.value)
        else {
            compositor.destroy()
            throw RuntimeError.bindFailed("wl_shm")
        }

        do {
            return try .init(pointer: shm, version: shmVersion, proxyAdoption: proxyAdoption)
        } catch {
            compositor.destroy()
            throw error
        }
    }

    @safe
    private func bindCompositor(
        registry reg: OpaquePointer,
        global compositorGlobal: RawGlobalAdvertisement,
        version compositorVersion: RawVersion
    ) throws -> RawCompositor {
        guard
            let compositor = unsafe swl_registry_bind_wl_compositor(
                reg,
                compositorGlobal.name,
                compositorVersion.value
            )
        else {
            throw RuntimeError.bindFailed("wl_compositor")
        }

        return try .init(
            pointer: compositor,
            version: compositorVersion,
            proxyAdoption: proxyAdoption
        )
    }

    @safe
    private func bindXDGWMBase(
        registry reg: OpaquePointer,
        global xdgGlobal: RawGlobalAdvertisement,
        version xdgVersion: RawVersion,
        compositor: RawCompositor,
        shm: RawSharedMemory
    ) throws -> RawXDGWMBase {
        guard
            let xdgWmBase = unsafe swl_registry_bind_xdg_wm_base(
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
            shm.destroy()
            compositor.destroy()
            throw error
        }
    }

    @safe
    private func bindSeatRegistry(
        registry reg: OpaquePointer,
        xdgWMBase: RawXDGWMBase,
        sharedMemory shm: RawSharedMemory,
        compositor: RawCompositor
    ) throws -> SeatRegistry {
        let seatRegistry = unsafe SeatRegistry(
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

    @safe
    private func bindOutputRegistry(
        registry reg: OpaquePointer,
        extensions: OptionalGlobals
    ) throws -> OutputRegistry {
        let outputRegistry = OutputRegistry(
            registry: reg,
            proxyAdoption: proxyAdoption,
            invariantFailureSink: invariantFailureSink,
            xdgOutputManager: extensions.xdgOutputManager
        )

        do {
            try outputRegistry.bindOutputs(from: registryState.snapshot)
            return outputRegistry
        } catch {
            outputRegistry.destroy()
            throw error
        }
    }

    private func bindTabletSeatRegistryIfPresent(
        extensions: OptionalGlobals,
        seatRegistry: SeatRegistry
    ) -> TabletSeatRegistry? {
        guard let tabletManager = extensions.tabletManager.boundObject else {
            return nil
        }

        let tabletSeatRegistry = TabletSeatRegistry(
            manager: tabletManager,
            eventSink: inputEventQueue
        )
        tabletSeatRegistry.bindTabletSeats(from: seatRegistry.seats)
        return tabletSeatRegistry
    }
}
