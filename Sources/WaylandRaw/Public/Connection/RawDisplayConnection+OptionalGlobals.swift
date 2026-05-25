import CWaylandProtocols

extension RawDisplayConnection {
    // swiftlint:disable cyclomatic_complexity function_body_length
    @safe
    package func bindOptionalGlobals(registry reg: OpaquePointer) throws -> OptionalGlobals {
        let decorationManager = try bindXDGDecorationManagerIfPresent(registry: reg)

        do {
            let xdgOutputManager = try bindXDGOutputManagerIfPresent(registry: reg)
            do {
                let viewporter = try bindViewporterIfPresent(registry: reg)
                do {
                    let presentation = try bindPresentationIfPresent(registry: reg)
                    do {
                        let fractionalScaleManager =
                            try bindFractionalScaleManagerIfPresent(registry: reg)
                        do {
                            let cursorShapeManager =
                                try bindCursorShapeManagerIfPresent(registry: reg)
                            do {
                                let dataDeviceManager =
                                    try bindDataDeviceManagerIfPresent(registry: reg)
                                do {
                                    let primarySelectionDeviceManager =
                                        try bindPrimarySelectionDeviceManagerIfPresent(
                                            registry: reg
                                        )
                                    do {
                                        let textInputManager =
                                            try bindTextInputManagerIfPresent(registry: reg)
                                        do {
                                            let linuxDmabuf = try bindLinuxDmabufIfPresent(
                                                registry: reg
                                            )
                                            do {
                                                let submitGlobals =
                                                    try bindSurfaceSubmitOptionalGlobalsIfPresent(
                                                        registry: reg
                                                    )
                                                do {
                                                    let metadataGlobals =
                                                        try
                                                        bindSurfaceMetadataOptionalGlobalsIfPresent(
                                                            registry: reg
                                                        )
                                                    do {
                                                        let xdgActivation =
                                                            try bindXDGActivationIfPresent(
                                                                registry: reg
                                                            )
                                                        return OptionalGlobals(
                                                            xdgDecorationManager:
                                                                decorationManager,
                                                            xdgOutputManager:
                                                                xdgOutputManager,
                                                            viewporter: viewporter,
                                                            presentation: presentation,
                                                            fractionalScaleManager:
                                                                fractionalScaleManager,
                                                            cursorShapeManager:
                                                                cursorShapeManager,
                                                            xdgActivation: xdgActivation,
                                                            linuxDrmSyncobjManager:
                                                                submitGlobals
                                                                .linuxDrmSyncobjManager,
                                                            fifoManager: submitGlobals.fifoManager,
                                                            commitTimingManager:
                                                                submitGlobals.commitTimingManager,
                                                            contentTypeManager:
                                                                metadataGlobals.contentTypeManager,
                                                            alphaModifierManager:
                                                                metadataGlobals.alphaModifierManager,
                                                            tearingControlManager:
                                                                metadataGlobals.tearingControlManager,
                                                            colorRepresentationManager:
                                                                metadataGlobals
                                                                .colorRepresentationManager,
                                                            colorManager:
                                                                metadataGlobals.colorManager,
                                                            dataDeviceManager: dataDeviceManager,
                                                            primarySelectionDeviceManager:
                                                                primarySelectionDeviceManager,
                                                            textInputManager: textInputManager,
                                                            linuxDmabuf: linuxDmabuf
                                                        )
                                                    } catch {
                                                        metadataGlobals.destroy()
                                                        throw error
                                                    }
                                                } catch {
                                                    submitGlobals.linuxDrmSyncobjManager.destroy()
                                                    submitGlobals.fifoManager.destroy()
                                                    submitGlobals.commitTimingManager.destroy()
                                                    throw error
                                                }
                                            } catch {
                                                linuxDmabuf.destroy()
                                                throw error
                                            }
                                        } catch {
                                            textInputManager.destroy()
                                            throw error
                                        }
                                    } catch {
                                        primarySelectionDeviceManager.destroy()
                                        throw error
                                    }
                                } catch {
                                    dataDeviceManager.destroy()
                                    throw error
                                }
                            } catch {
                                cursorShapeManager.destroy()
                                throw error
                            }
                        } catch {
                            fractionalScaleManager.destroy()
                            throw error
                        }
                    } catch {
                        presentation.destroy()
                        throw error
                    }
                } catch {
                    viewporter.destroy()
                    throw error
                }
            } catch {
                xdgOutputManager.destroy()
                throw error
            }
        } catch {
            decorationManager.destroy()
            throw error
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

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
    private func bindXDGOutputManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalXDGOutputManager {
        guard let global = optionalGlobal(named: "zxdg_output_manager_v1") else {
            return .missing
        }

        switch Self.xdgOutputManagerBindingDecision(global) {
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
                throw RuntimeError.bindFailed("zxdg_output_manager_v1")
            }

            let wrappedManager = try RawXDGOutputManager(
                pointer: manager,
                version: version,
                proxyAdoption: proxyAdoption
            )
            return .bound(wrappedManager)
        }
    }

    package static func shouldBindXDGOutputManager(
        _ global: RawGlobalAdvertisement
    ) -> Bool {
        global.advertisedVersion >= SupportedVersions.zxdgOutputManagerV1Minimum
    }

    package static func xdgOutputManagerBindingDecision(
        _ global: RawGlobalAdvertisement
    ) -> XDGOutputManagerBindingDecision {
        guard shouldBindXDGOutputManager(global) else {
            return .unsupportedVersion(
                advertised: global.advertisedVersion,
                minimum: SupportedVersions.zxdgOutputManagerV1Minimum
            )
        }

        return .bind(
            version: global.negotiatedVersion(
                supportedByClient: SupportedVersions.zxdgOutputManagerV1
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
    private func bindPresentationIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalPresentation {
        guard let global = optionalGlobal(named: "wp_presentation") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpPresentation
        )

        guard
            let presentation = unsafe swl_registry_bind_wp_presentation(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_presentation")
        }

        let wrappedPresentation = try RawPresentation(
            pointer: presentation,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedPresentation)
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
    private func bindCursorShapeManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalCursorShapeManager {
        guard let global = optionalGlobal(named: "wp_cursor_shape_manager_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wpCursorShapeManagerV1
        )

        guard
            let manager = unsafe swl_registry_bind_wp_cursor_shape_manager_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wp_cursor_shape_manager_v1")
        }

        let wrappedManager = try RawCursorShapeManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    private func bindXDGActivationIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalXDGActivation {
        guard let global = optionalGlobal(named: "xdg_activation_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.xdgActivationV1
        )

        guard
            let activation = unsafe swl_registry_bind_xdg_activation_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("xdg_activation_v1")
        }

        let wrappedActivation = try RawXDGActivation(
            pointer: activation,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedActivation)
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

    @safe
    private func bindTextInputManagerIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalTextInputManager {
        guard let global = optionalGlobal(named: "zwp_text_input_manager_v3") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.zwpTextInputManagerV3
        )

        guard
            let manager = unsafe swl_registry_bind_zwp_text_input_manager_v3(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("zwp_text_input_manager_v3")
        }

        let wrappedManager = try RawTextInputManager(
            pointer: manager,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedManager)
    }

    @safe
    private func bindLinuxDmabufIfPresent(
        registry reg: OpaquePointer
    ) throws -> OptionalLinuxDmabuf {
        guard let global = optionalGlobal(named: "zwp_linux_dmabuf_v1") else {
            return .missing
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.zwpLinuxDmabufV1
        )

        guard
            let linuxDmabuf = unsafe swl_registry_bind_zwp_linux_dmabuf_v1(
                reg,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("zwp_linux_dmabuf_v1")
        }

        let wrappedLinuxDmabuf = try RawLinuxDmabuf(
            pointer: linuxDmabuf,
            version: version,
            proxyAdoption: proxyAdoption
        )
        return .bound(wrappedLinuxDmabuf)
    }
}
