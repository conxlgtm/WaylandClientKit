import CWaylandProtocols

extension RawDisplayConnection {
    @safe
    package func bindWlrOutputManagerOneShot(
        onEvent: ((RawWlrOutputManagerEvent) -> Void)? = nil
    ) throws -> RawWlrOutputManager? {
        preconditionIsOwnerThread()
        guard let global = optionalGlobal(named: "zwlr_output_manager_v1") else {
            return nil
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.zwlrOutputManagerV1
        )
        guard
            let manager = unsafe swl_registry_bind_zwlr_output_manager_v1(
                registry.opaquePointer,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("zwlr_output_manager_v1")
        }

        return try RawWlrOutputManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption,
            onEvent: onEvent
        )
    }
}
