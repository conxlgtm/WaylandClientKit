import CWaylandProtocols

package struct SurfaceMetadataOptionalGlobals {
    package let contentTypeManager: OptionalContentTypeManager
    package let alphaModifierManager: OptionalAlphaModifierManager
    package let tearingControlManager: OptionalTearingControlManager
    package let colorRepresentationManager: OptionalColorRepresentationManager
    package let colorManager: OptionalColorManager

    package func destroy() {
        colorManager.destroy()
        colorRepresentationManager.destroy()
        tearingControlManager.destroy()
        alphaModifierManager.destroy()
        contentTypeManager.destroy()
    }
}

extension RawDisplayConnection {
    @safe
    package func bindSurfaceMetadataOptionalGlobalsIfPresent(
        registry reg: OpaquePointer
    ) throws -> SurfaceMetadataOptionalGlobals {
        let rollback = OptionalGlobalRollback()
        let contentTypeManager = try bindContentTypeManagerIfPresent(registry: reg)
        rollback.append { contentTypeManager.destroy() }
        let alphaModifierManager = try bindAlphaModifierManagerIfPresent(registry: reg)
        rollback.append { alphaModifierManager.destroy() }
        let tearingControlManager = try bindTearingControlManagerIfPresent(registry: reg)
        rollback.append { tearingControlManager.destroy() }
        let colorRepresentationManager =
            try bindColorRepresentationManagerIfPresent(registry: reg)
        rollback.append { colorRepresentationManager.destroy() }
        let colorManager = try bindColorManagerIfPresent(registry: reg)
        rollback.append { colorManager.destroy() }
        rollback.disarm()
        return SurfaceMetadataOptionalGlobals(
            contentTypeManager: contentTypeManager,
            alphaModifierManager: alphaModifierManager,
            tearingControlManager: tearingControlManager,
            colorRepresentationManager: colorRepresentationManager,
            colorManager: colorManager
        )
    }

    @safe
    private func bindContentTypeManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalContentTypeManager {
        guard let global = optionalGlobal(named: "wp_content_type_manager_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpContentTypeManagerV1
        )

        guard
            let manager = unsafe swl_registry_bind_wp_content_type_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_content_type_manager_v1")
        }

        let wrappedManager = try RawContentTypeManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    private func bindAlphaModifierManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalAlphaModifierManager {
        guard let global = optionalGlobal(named: "wp_alpha_modifier_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpAlphaModifierV1
        )

        guard
            let manager = unsafe swl_registry_bind_wp_alpha_modifier_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_alpha_modifier_v1")
        }

        let wrappedManager = try RawAlphaModifierManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    private func bindTearingControlManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalTearingControlManager {
        guard let global = optionalGlobal(named: "wp_tearing_control_manager_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpTearingControlManagerV1
        )

        guard
            let manager = unsafe swl_registry_bind_wp_tearing_control_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_tearing_control_manager_v1")
        }

        let wrappedManager = try RawTearingControlManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    private func bindColorRepresentationManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalColorRepresentationManager {
        guard
            let global = optionalGlobal(named: "wp_color_representation_manager_v1")
        else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpColorRepresentationManagerV1
        )

        guard
            let manager = unsafe swl_registry_bind_wp_color_representation_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_color_representation_manager_v1")
        }

        let wrappedManager = try RawColorRepresentationManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    private func bindColorManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalColorManager {
        guard let global = optionalGlobal(named: "wp_color_manager_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpColorManagerV1
        )

        guard
            let manager = unsafe swl_registry_bind_wp_color_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_color_manager_v1")
        }

        let wrappedManager = try RawColorManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }
}
