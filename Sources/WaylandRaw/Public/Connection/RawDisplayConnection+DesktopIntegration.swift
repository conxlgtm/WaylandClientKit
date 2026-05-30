import CWaylandProtocols

extension RawDisplayConnection {
    @safe
    package func bindToplevelIconManagerOneShot() throws -> RawXDGToplevelIconManager? {
        preconditionIsOwnerThread()
        guard let global = optionalGlobal(named: "xdg_toplevel_icon_manager_v1") else {
            return nil
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.xdgToplevelIconManagerV1
        )
        guard
            let manager = unsafe swl_registry_bind_xdg_toplevel_icon_manager_v1(
                registry.opaquePointer,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("xdg_toplevel_icon_manager_v1")
        }

        return try RawXDGToplevelIconManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }

    @safe
    package func bindIdleInhibitManagerOneShot() throws -> RawIdleInhibitManager? {
        preconditionIsOwnerThread()
        guard let global = optionalGlobal(named: "zwp_idle_inhibit_manager_v1") else {
            return nil
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.zwpIdleInhibitManagerV1
        )
        guard
            let manager = unsafe swl_registry_bind_zwp_idle_inhibit_manager_v1(
                registry.opaquePointer,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("zwp_idle_inhibit_manager_v1")
        }

        return try RawIdleInhibitManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }

    @safe
    package func bindSystemBellOneShot() throws -> RawSystemBell? {
        preconditionIsOwnerThread()
        guard let global = optionalGlobal(named: "xdg_system_bell_v1") else {
            return nil
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.xdgSystemBellV1
        )
        guard
            let bell = unsafe swl_registry_bind_xdg_system_bell_v1(
                registry.opaquePointer,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("xdg_system_bell_v1")
        }

        return try RawSystemBell(
            pointer: bell,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }
}
