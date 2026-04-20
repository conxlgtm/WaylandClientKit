import CWaylandClientSystem
import CWaylandProtocols

public final class RawDisplayConnection {
    public let display: RawDisplay
    public let registry: RawRegistry
    public private(set) var boundGlobals: BoundGlobals?

    private let registryState: RegistryState
    private let registryListenerOwner: RegistryListenerOwner

    private init(
        display: RawDisplay,
        registry: RawRegistry,
        registryState: RegistryState,
        registryListenerOwner: RegistryListenerOwner
    ) {
        self.display = display
        self.registry = registry
        self.registryState = registryState
        self.registryListenerOwner = registryListenerOwner
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
        guard let syncCallback = swl_display_sync(self.display.opaquePointer) else {
            throw RuntimeError.syncRequestFailed
        }
        defer { swl_callback_destroy(syncCallback) }

        let waiter = SyncCallbackOwner()
        try waiter.install(on: syncCallback)

        while !waiter.didFire {
            try EventLoop.pumpOnce(
                display: self.display.opaquePointer,
                timeoutMilliseconds: 1000
            )
        }
    }

    public var globals: [RawGlobalAdvertisement] {
        self.registryState.snapshot
    }

    public func global(named interfaceName: String) -> RawGlobalAdvertisement? {
        self.registryState.firstGlobal(named: interfaceName)
    }

    @discardableResult
    public func bindRequiredGlobals() throws -> BoundGlobals {
        if let boundGlobals {
            return boundGlobals
        }

        let reg = self.registry.opaquePointer

        guard let compositorGlobal = self.registryState.firstGlobal(named: "wl_compositor") else {
            throw RuntimeError.missingRequiredGlobal("wl_compositor")
        }
        guard let shmGlobal = self.registryState.firstGlobal(named: "wl_shm") else {
            throw RuntimeError.missingRequiredGlobal("wl_shm")
        }
        guard let xdgGlobal = self.registryState.firstGlobal(named: "xdg_wm_base") else {
            throw RuntimeError.missingRequiredGlobal("xdg_wm_base")
        }

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

        guard
            let shm = swl_registry_bind_wl_shm(
                reg,
                shmGlobal.name,
                shmVersion.value
            )
        else {
            swl_compositor_destroy(compositor)
            throw RuntimeError.bindFailed("wl_shm")
        }

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

        // wl_seat is optional
        var seat: OpaquePointer? = nil
        var seatVersion: RawVersion? = nil
        if let seatGlobal = self.registryState.firstGlobal(named: "wl_seat") {
            let negotiated = seatGlobal.negotiatedVersion(
                supportedByClient: SupportedVersions.wlSeat
            )
            if let seatPointer = swl_registry_bind_wl_seat(
                reg,
                seatGlobal.name,
                negotiated.value
            ) {
                seat = seatPointer
                seatVersion = negotiated
            }
        }

        let bound = BoundGlobals(
            compositor: compositor,
            compositorVersion: compositorVersion,
            shm: shm,
            shmVersion: shmVersion,
            xdgWmBase: xdgWmBase,
            xdgWmBaseVersion: xdgVersion,
            seat: seat,
            seatVersion: seatVersion
        )

        self.boundGlobals = bound
        return bound
    }

    public func pumpEvents(timeoutMilliseconds: Int32 = -1) throws {
        try EventLoop.pumpOnce(
            display: self.display.opaquePointer,
            timeoutMilliseconds: timeoutMilliseconds
        )
    }

    public func runEventLoop(while shouldContinue: () -> Bool) throws {
        try EventLoop.run(
            display: self.display.opaquePointer,
            shouldContinue: shouldContinue
        )
    }

    deinit {
        self.boundGlobals?.destroy()
        swl_registry_destroy(self.registry.opaquePointer)
        wl_display_disconnect(self.display.opaquePointer)
    }
}
