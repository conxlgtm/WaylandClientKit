import CWaylandProtocols

extension RawDisplayConnection {
    @safe
    func bindContentTypeManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalContentTypeManager {
        let descriptor = OptionalGlobalDescriptors.wpContentTypeManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_wp_content_type_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawContentTypeManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindAlphaModifierManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalAlphaModifierManager {
        let descriptor = OptionalGlobalDescriptors.wpAlphaModifierV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_wp_alpha_modifier_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawAlphaModifierManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindTearingControlManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalTearingControlManager {
        let descriptor = OptionalGlobalDescriptors.wpTearingControlManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_wp_tearing_control_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawTearingControlManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindColorRepresentationManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalColorRepresentationManager {
        let descriptor = OptionalGlobalDescriptors.wpColorRepresentationManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_wp_color_representation_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawColorRepresentationManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindColorManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalColorManager {
        let descriptor = OptionalGlobalDescriptors.wpColorManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_wp_color_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawColorManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }
}
