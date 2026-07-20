import CWaylandProtocols

extension RawDisplayConnection {
    @safe
    func bindLinuxDrmSyncobjManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalLinuxDrmSyncobjManager {
        let descriptor = OptionalGlobalDescriptors.wpLinuxDrmSyncobjManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_wp_linux_drm_syncobj_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawLinuxDrmSyncobjManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindFifoManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalFifoManager {
        let descriptor = OptionalGlobalDescriptors.wpFifoManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_wp_fifo_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawFifoManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindCommitTimingManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalCommitTimingManager {
        let descriptor = OptionalGlobalDescriptors.wpCommitTimingManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_wp_commit_timing_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawCommitTimingManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }
}
