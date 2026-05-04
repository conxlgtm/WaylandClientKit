import CWaylandProtocols

extension RawDisplayConnection {
    package func bindOptionalGlobals(registry reg: OpaquePointer) throws -> OptionalGlobals {
        let decorationManager = try bindXDGDecorationManagerIfPresent(registry: reg)

        do {
            let viewporter = try bindViewporterIfPresent(registry: reg)
            do {
                let fractionalScaleManager = try bindFractionalScaleManagerIfPresent(
                    registry: reg
                )
                return OptionalGlobals(
                    xdgDecorationManager: decorationManager,
                    viewporter: viewporter,
                    fractionalScaleManager: fractionalScaleManager
                )
            } catch {
                viewporter.destroy()
                throw error
            }
        } catch {
            decorationManager.destroy()
            throw error
        }
    }

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

            let wrappedManager = try unsafe RawXDGDecorationManager(
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

        let wrappedViewporter = try unsafe RawViewporter(
            pointer: viewporter,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedViewporter)
    }

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

        let wrappedManager = try unsafe RawFractionalScaleManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }
}
