import CWaylandProtocols

extension RawDisplayConnection {
    @safe
    package func bindOptionalGlobals(registry reg: OpaquePointer) throws -> OptionalGlobals {
        let decorationManager = try bindXDGDecorationManagerIfPresent(registry: reg)

        do {
            let viewporter = try bindViewporterIfPresent(registry: reg)
            do {
                let fractionalScaleManager = try bindFractionalScaleManagerIfPresent(
                    registry: reg
                )
                do {
                    let dataDeviceManager = try bindDataDeviceManagerIfPresent(registry: reg)
                    do {
                        let primarySelectionDeviceManager =
                            try bindPrimarySelectionDeviceManagerIfPresent(registry: reg)
                        return OptionalGlobals(
                            xdgDecorationManager: decorationManager,
                            viewporter: viewporter,
                            fractionalScaleManager: fractionalScaleManager,
                            dataDeviceManager: dataDeviceManager,
                            primarySelectionDeviceManager: primarySelectionDeviceManager
                        )
                    } catch {
                        dataDeviceManager.destroy()
                        throw error
                    }
                } catch {
                    fractionalScaleManager.destroy()
                    throw error
                }
            } catch {
                viewporter.destroy()
                throw error
            }
        } catch {
            decorationManager.destroy()
            throw error
        }
    }

    @safe
    private func bindXDGDecorationManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalXDGDecorationManager {
        guard let global = optionalGlobal(named: "zxdg_decoration_manager_v1") else {
            return .missing
        }

        switch Self.xdgDecorationManagerBindingDecision(global) {
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
                throw RuntimeError.bindFailed("zxdg_decoration_manager_v1")
            }

            let wrappedManager = try RawXDGDecorationManager(
                pointer: manager,
                version: version,
                proxyAdoption: proxyAdoption
            )
            return .bound(wrappedManager)
        }
    }

    package static func shouldBindXDGDecorationManager(
        _ global: RawGlobalAdvertisement
    ) -> Bool {
        global.advertisedVersion >= SupportedVersions.zxdgDecorationManagerV1Minimum
    }

    package static func xdgDecorationManagerBindingDecision(
        _ global: RawGlobalAdvertisement
    ) -> XDGDecorationManagerBindingDecision {
        guard shouldBindXDGDecorationManager(global) else {
            return .unsupportedVersion(
                advertised: global.advertisedVersion,
                minimum: SupportedVersions.zxdgDecorationManagerV1Minimum
            )
        }

        return .bind(
            version: global.negotiatedVersion(
                supportedByClient: SupportedVersions.zxdgDecorationManagerV1
            )
        )
    }

    @safe
    private func bindViewporterIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalViewporter {
        guard let global = optionalGlobal(named: "wp_viewporter") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpViewporter
        )

        guard
            let viewporter = unsafe swl_registry_bind_wp_viewporter(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_viewporter")
        }

        let wrappedViewporter = try RawViewporter(
            pointer: viewporter,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedViewporter)
    }

    @safe
    private func bindFractionalScaleManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalFractionalScaleManager {
        guard let global = optionalGlobal(named: "wp_fractional_scale_manager_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpFractionalScaleManagerV1
        )

        guard
            let manager = unsafe swl_registry_bind_wp_fractional_scale_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_fractional_scale_manager_v1")
        }

        let wrappedManager = try RawFractionalScaleManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    private func bindDataDeviceManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalDataDeviceManager {
        guard let global = optionalGlobal(named: "wl_data_device_manager") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wlDataDeviceManager
        )

        guard
            let manager = unsafe swl_registry_bind_wl_data_device_manager(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wl_data_device_manager")
        }

        let wrappedManager = try RawDataDeviceManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    private func bindPrimarySelectionDeviceManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalPrimarySelectionDeviceManager {
        guard let global = optionalGlobal(named: "zwp_primary_selection_device_manager_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.zwpPrimarySelectionDeviceManagerV1
        )

        guard
            let manager = unsafe swl_registry_bind_zwp_primary_selection_device_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("zwp_primary_selection_device_manager_v1")
        }

        let wrappedManager = try RawPrimarySelectionDeviceManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }
}
