import CWaylandProtocols

extension RawDisplayConnection {
    @safe
    package func bindCompositorSessionManagerOneShot()
        throws -> RawCompositorSessionManager?
    {
        preconditionIsOwnerThread()
        guard let global = optionalGlobal(named: "xdg_session_manager_v1") else {
            return nil
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.xdgSessionManagerV1
        )
        guard
            let manager = unsafe swl_registry_bind_xdg_session_manager_v1(
                registry.opaquePointer,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("xdg_session_manager_v1")
        }

        return try RawCompositorSessionManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }
}
