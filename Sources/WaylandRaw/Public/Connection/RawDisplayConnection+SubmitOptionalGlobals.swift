import CWaylandProtocols

package struct SurfaceSubmitOptionalGlobals {
    package let linuxDrmSyncobjManager: OptionalLinuxDrmSyncobjManager
    package let fifoManager: OptionalFifoManager
    package let commitTimingManager: OptionalCommitTimingManager

    package func destroy() {
        commitTimingManager.destroy()
        fifoManager.destroy()
        linuxDrmSyncobjManager.destroy()
    }
}

extension RawDisplayConnection {
    @safe
    package func bindSurfaceSubmitOptionalGlobalsIfPresent(
        registry reg: OpaquePointer
    ) throws -> SurfaceSubmitOptionalGlobals {
        let rollback = OptionalGlobalRollback()
        let syncobjManager = try bindLinuxDrmSyncobjManagerIfPresent(registry: reg)
        rollback.append { syncobjManager.destroy() }
        let fifoManager = try bindFifoManagerIfPresent(registry: reg)
        rollback.append { fifoManager.destroy() }
        let commitTimingManager = try bindCommitTimingManagerIfPresent(registry: reg)
        rollback.append { commitTimingManager.destroy() }
        rollback.disarm()
        return SurfaceSubmitOptionalGlobals(
            linuxDrmSyncobjManager: syncobjManager,
            fifoManager: fifoManager,
            commitTimingManager: commitTimingManager
        )
    }

    @safe
    private func bindLinuxDrmSyncobjManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalLinuxDrmSyncobjManager {
        guard let global = optionalGlobal(named: "wp_linux_drm_syncobj_manager_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpLinuxDrmSyncobjManagerV1
        )

        guard
            let manager = unsafe swl_registry_bind_wp_linux_drm_syncobj_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_linux_drm_syncobj_manager_v1")
        }

        let wrappedManager = try RawLinuxDrmSyncobjManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    private func bindFifoManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalFifoManager {
        guard let global = optionalGlobal(named: "wp_fifo_manager_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpFifoManagerV1
        )

        guard
            let manager = unsafe swl_registry_bind_wp_fifo_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_fifo_manager_v1")
        }

        let wrappedManager = try RawFifoManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    private func bindCommitTimingManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalCommitTimingManager {
        guard let global = optionalGlobal(named: "wp_commit_timing_manager_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpCommitTimingManagerV1
        )

        guard
            let manager = unsafe swl_registry_bind_wp_commit_timing_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_commit_timing_manager_v1")
        }

        let wrappedManager = try RawCommitTimingManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }
}
