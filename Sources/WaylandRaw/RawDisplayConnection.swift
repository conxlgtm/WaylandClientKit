import CWaylandClientSystem
import CWaylandProtocols

public final class RawDisplayConnection {
    public let display: RawDisplay
    public let registry: RawRegistry
    public private(set) var boundGlobals: BoundGlobals?
    private var xdgWmBaseOwner: XDGWMBaseOwner?

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
            throw RuntimeError.syncRequestFailed
        }
        defer { swl_callback_destroy(syncCallback) }

        let waiter = SyncCallbackOwner()
        try waiter.install(on: syncCallback)

        while !waiter.didFire {
            try EventLoop.pumpOnce(
                display: display.opaquePointer,
                timeoutMilliseconds: 1_000
            )
        }
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

        let shm = try bindSharedMemory(
            registry: reg,
            global: shmGlobal,
            version: shmVersion,
            compositor: compositor
        )
        let xdgWmBase = try bindXDGWMBase(
            registry: reg,
            global: xdgGlobal,
            version: xdgVersion,
            compositor: compositor,
            shm: shm
        )
        let wmBaseOwner = try installXDGWMBaseListener(
            on: xdgWmBase,
            shm: shm,
            compositor: compositor
        )
        let seatBinding = bindSeatIfAvailable(registry: reg)

        let bound = BoundGlobals(
            compositor: compositor,
            compositorVersion: compositorVersion,
            shm: shm,
            shmVersion: shmVersion,
            xdgWmBase: xdgWmBase,
            xdgWmBaseVersion: xdgVersion,
            seat: seatBinding.pointer,
            seatVersion: seatBinding.version
        )

        boundGlobals = bound
        xdgWmBaseOwner = wmBaseOwner
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
        compositor: OpaquePointer
    ) throws -> OpaquePointer {
        guard let shm = swl_registry_bind_wl_shm(reg, shmGlobal.name, shmVersion.value) else {
            swl_compositor_destroy(compositor)
            throw RuntimeError.bindFailed("wl_shm")
        }

        return shm
    }

    private func bindXDGWMBase(
        registry reg: OpaquePointer,
        global xdgGlobal: RawGlobalAdvertisement,
        version xdgVersion: RawVersion,
        compositor: OpaquePointer,
        shm: OpaquePointer
    ) throws -> OpaquePointer {
        guard
            let xdgWmBase = swl_registry_bind_xdg_wm_base(
                reg,
                xdgGlobal.name,
                xdgVersion.value
            )
        else {
            swl_shm_destroy(shm)
            swl_compositor_destroy(compositor)
            throw RuntimeError.bindFailed("xdg_wm_base")
        }

        return xdgWmBase
    }

    private func installXDGWMBaseListener(
        on xdgWmBase: OpaquePointer,
        shm: OpaquePointer,
        compositor: OpaquePointer
    ) throws -> XDGWMBaseOwner {
        let owner = XDGWMBaseOwner(wmBase: xdgWmBase)
        do {
            try owner.install()
        } catch {
            swl_xdg_wm_base_destroy(xdgWmBase)
            swl_shm_destroy(shm)
            swl_compositor_destroy(compositor)
            throw error
        }

        return owner
    }

    private func bindSeatIfAvailable(
        registry reg: OpaquePointer
    ) -> (pointer: OpaquePointer?, version: RawVersion?) {
        guard let seatGlobal = registryState.firstGlobal(named: "wl_seat") else {
            return (nil, nil)
        }

        let negotiated = seatGlobal.negotiatedVersion(
            supportedByClient: SupportedVersions.wlSeat
        )
        let seat = swl_registry_bind_wl_seat(reg, seatGlobal.name, negotiated.value)
        return (seat, seat == nil ? nil : negotiated)
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
