import CWaylandClientSystem
import CWaylandProtocols

public final class RawDisplayConnection {
    let display: RawDisplay
    let registry: RawRegistry
    public private(set) var boundGlobals: BoundGlobals?

    private let registryState: RegistryState
    private let registryListenerOwner: RegistryListenerOwner

    private init(
        display rawDisplay: RawDisplay,
        registry rawRegistry: RawRegistry,
        registryState rawRegistryState: RegistryState,
        registryListenerOwner rawRegistryListenerOwner: RegistryListenerOwner
    ) {
        display = rawDisplay
        registry = rawRegistry
        registryState = rawRegistryState
        registryListenerOwner = rawRegistryListenerOwner
    }

    public static func connect() throws -> RawDisplayConnection {
        guard let displayPointer = wl_display_connect(nil) else {
            throw RuntimeError.connectionFailed
        }

        let rawDisplay = RawDisplay(
            opaquePointer: displayPointer,
            version: 1,
            ownership: .connectionLifetime
        )

        guard let registryPointer = swl_display_get_registry(displayPointer) else {
            wl_display_disconnect(displayPointer)
            throw RuntimeError.registryCreationFailed
        }

        let state = RegistryState()
        let listenerOwner = RegistryListenerOwner(state: state)

        let rawRegistry = RawRegistry(
            opaquePointer: registryPointer,
            version: 1,
            ownership: .connectionLifetime
        )

        do {
            try listenerOwner.install(on: registryPointer)
        } catch {
            swl_registry_destroy(registryPointer)
            wl_display_disconnect(displayPointer)
            throw error
        }

        return RawDisplayConnection(
            display: rawDisplay,
            registry: rawRegistry,
            registryState: state,
            registryListenerOwner: listenerOwner
        )
    }

    public func completeInitialDiscovery() throws {
        guard let syncCallback = swl_display_sync(display.opaquePointer) else {
            throw RuntimeError.displaySyncRequestFailed
        }

        var didFire = false
        let registration = try FrameCallbackRegistration(pointer: syncCallback) {
            didFire = true
        }

        while !didFire {
            try EventLoop.pumpOnce(
                display: display.opaquePointer,
                timeoutMilliseconds: 1_000
            )
        }

        registration.keepAliveUntilHere()
    }

    public var globals: [RawGlobalAdvertisement] {
        registryState.snapshot
    }

    public func global(named interfaceName: String) -> RawGlobalAdvertisement? {
        registryState.firstGlobal(named: interfaceName)
    }

    @discardableResult
    public func bindRequiredGlobals() throws -> BoundGlobals {
        if let boundGlobals {
            return boundGlobals
        }

        let reg = registry.opaquePointer
        let compositorGlobal = try requiredGlobal(named: "wl_compositor")
        let shmGlobal = try requiredGlobal(named: "wl_shm")
        let xdgGlobal = try requiredGlobal(named: "xdg_wm_base")
        let compositorVersion = compositorGlobal.negotiatedVersion(
            supportedByClient: SupportedVersions.wlCompositor
        )
        let shmVersion = shmGlobal.negotiatedVersion(
            supportedByClient: SupportedVersions.wlShm
        )
        let xdgVersion = xdgGlobal.negotiatedVersion(
            supportedByClient: SupportedVersions.xdgWmBase
        )

        guard
            let compositor = swl_registry_bind_wl_compositor(
                reg,
                compositorGlobal.name,
                compositorVersion.value
            )
        else {
            throw RuntimeError.bindFailed("wl_compositor")
        }
        let compositorWrapper = RawCompositor(
            pointer: compositor,
            version: compositorVersion
        )

        let shm = try bindSharedMemory(
            registry: reg,
            global: shmGlobal,
            version: shmVersion,
            compositor: compositorWrapper
        )
        let xdgWmBase = try bindXDGWMBase(
            registry: reg,
            global: xdgGlobal,
            version: xdgVersion,
            compositor: compositorWrapper,
            shm: shm
        )
        let seatBinding = bindSeatIfAvailable(registry: reg)

        let bound = BoundGlobals(
            compositor: compositorWrapper,
            sharedMemory: shm,
            xdgWMBase: xdgWmBase,
            seat: seatBinding
        )

        boundGlobals = bound
        return bound
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

        return .init(pointer: shm, version: shmVersion)
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
            return try .init(pointer: xdgWmBase, version: xdgVersion)
        } catch {
            swl_xdg_wm_base_destroy(xdgWmBase)
            shm.destroy()
            compositor.destroy()
            throw error
        }
    }

    private func bindSeatIfAvailable(
        registry reg: OpaquePointer
    ) -> RawSeat? {
        guard let seatGlobal = registryState.firstGlobal(named: "wl_seat") else {
            return nil
        }

        let negotiated = seatGlobal.negotiatedVersion(
            supportedByClient: SupportedVersions.wlSeat
        )
        guard let seat = swl_registry_bind_wl_seat(reg, seatGlobal.name, negotiated.value) else {
            return nil
        }

        return .init(pointer: seat, version: negotiated)
    }

    public func pumpEvents(timeoutMilliseconds: Int32 = -1) throws {
        try EventLoop.pumpOnce(
            display: display.opaquePointer,
            timeoutMilliseconds: timeoutMilliseconds
        )
    }

    public func runEventLoop(while shouldContinue: () -> Bool) throws {
        try EventLoop.run(
            display: display.opaquePointer,
            shouldContinue: shouldContinue
        )
    }

    deinit {
        boundGlobals?.destroy()
        swl_registry_destroy(registry.opaquePointer)
        wl_display_disconnect(display.opaquePointer)
    }
}
