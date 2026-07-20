// swiftlint:disable file_length

import CWaylandProtocols

extension RawDisplayConnection {
    @safe
    func bindXDGDecorationManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalXDGDecorationManager {
        let descriptor = OptionalGlobalDescriptors.zxdgDecorationManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        switch descriptor.bindingDecision(for: global) {
        case .unsupportedVersion(let advertised, let minimum):
            return .unsupportedVersion(advertised: advertised, minimum: minimum)
        case .bind(let version):
            guard
                let manager = unsafe swl_registry_bind_zxdg_decoration_manager_v1(
                    reg,
                    global.name,
                    version.value
                )
            else {
                throw RuntimeError.bindFailed(descriptor.interfaceName)
            }

            let wrappedManager = try RawXDGDecorationManager(
                pointer: manager,
                version: version,
                proxyAdoption: proxyAdoption
            )
            return .bound(wrappedManager)
        }
    }

    @safe
    func bindXDGToplevelIconManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalXDGToplevelIconManager {
        let descriptor = OptionalGlobalDescriptors.xdgToplevelIconManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)
        guard
            let manager = unsafe swl_registry_bind_xdg_toplevel_icon_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        return .bound(
            try RawXDGToplevelIconManager(
                pointer: manager,
                version: version,
                proxyAdoption: proxyAdoption
            )
        )
    }

    @safe
    func bindXDGOutputManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalXDGOutputManager {
        let descriptor = OptionalGlobalDescriptors.zxdgOutputManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        switch descriptor.bindingDecision(for: global) {
        case .unsupportedVersion(let advertised, let minimum):
            return .unsupportedVersion(
                advertised: advertised,
                minimum: minimum
            )
        case .bind(let version):
            guard
                let manager = unsafe swl_registry_bind_zxdg_output_manager_v1(
                    reg,
                    global.name,
                    version.value
                )
            else {
                throw RuntimeError.bindFailed(descriptor.interfaceName)
            }

            let wrappedManager = try RawXDGOutputManager(
                pointer: manager,
                version: version,
                proxyAdoption: proxyAdoption
            )
            return .bound(wrappedManager)
        }
    }

    @safe
    func bindViewporterIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalViewporter {
        let descriptor = OptionalGlobalDescriptors.wpViewporter
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let viewporter = unsafe swl_registry_bind_wp_viewporter(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedViewporter = try RawViewporter(
            pointer: viewporter,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedViewporter)
    }

    @safe
    func bindPresentationIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalPresentation {
        let descriptor = OptionalGlobalDescriptors.wpPresentation
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let presentation = unsafe swl_registry_bind_wp_presentation(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedPresentation = try RawPresentation(
            pointer: presentation,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedPresentation)
    }

    @safe
    func bindFractionalScaleManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalFractionalScaleManager {
        let descriptor = OptionalGlobalDescriptors.wpFractionalScaleManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_wp_fractional_scale_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawFractionalScaleManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindCursorShapeManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalCursorShapeManager {
        let descriptor = OptionalGlobalDescriptors.wpCursorShapeManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_wp_cursor_shape_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawCursorShapeManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindXDGActivationIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalXDGActivation {
        let descriptor = OptionalGlobalDescriptors.xdgActivationV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let activation = unsafe swl_registry_bind_xdg_activation_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedActivation = try RawXDGActivation(
            pointer: activation,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedActivation)
    }

    @safe
    func bindCompositorSessionManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalCompositorSessionManager {
        let descriptor = OptionalGlobalDescriptors.xdgSessionManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_xdg_session_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawCompositorSessionManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindRelativePointerManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalRelativePointerManager {
        let descriptor = OptionalGlobalDescriptors.zwpRelativePointerManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_zwp_relative_pointer_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawRelativePointerManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindPointerWarpIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalPointerWarp {
        let descriptor = OptionalGlobalDescriptors.wpPointerWarpV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let warp = unsafe swl_registry_bind_wp_pointer_warp_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedWarp = try RawPointerWarp(
            pointer: warp,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedWarp)
    }

    @safe
    func bindTabletManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalTabletManager {
        let descriptor = OptionalGlobalDescriptors.zwpTabletManagerV2
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_zwp_tablet_manager_v2(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawTabletManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindPointerConstraintsIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalPointerConstraints {
        let descriptor = OptionalGlobalDescriptors.zwpPointerConstraintsV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let constraints = unsafe swl_registry_bind_zwp_pointer_constraints_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedConstraints = try RawPointerConstraints(
            pointer: constraints,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedConstraints)
    }

    @safe
    func bindDataDeviceManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalDataDeviceManager {
        let descriptor = OptionalGlobalDescriptors.wlDataDeviceManager
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_wl_data_device_manager(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawDataDeviceManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindPrimarySelectionDeviceManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalPrimarySelectionDeviceManager {
        let descriptor = OptionalGlobalDescriptors.zwpPrimarySelectionDeviceManagerV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_zwp_primary_selection_device_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawPrimarySelectionDeviceManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindTextInputManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalTextInputManager {
        let descriptor = OptionalGlobalDescriptors.zwpTextInputManagerV3
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let manager = unsafe swl_registry_bind_zwp_text_input_manager_v3(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedManager = try RawTextInputManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    func bindLinuxDmabufIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalLinuxDmabuf {
        let descriptor = OptionalGlobalDescriptors.zwpLinuxDmabufV1
        guard let global = optionalGlobal(named: descriptor.interfaceName) else {
            return .missing
        }

        let version = descriptor.negotiatedVersion(for: global)

        guard
            let linuxDmabuf = unsafe swl_registry_bind_zwp_linux_dmabuf_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed(descriptor.interfaceName)
        }

        let wrappedLinuxDmabuf = try RawLinuxDmabuf(
            pointer: linuxDmabuf,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedLinuxDmabuf)
    }
}
