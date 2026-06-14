import Testing

@testable import WaylandClient

@Suite
struct WaylandCapabilitiesTests {
    @Test
    func missingProtocolsAreUnavailable() {
        let capabilities = WaylandCapabilities.fromAdvertisedProtocols([])

        #expect(capabilities.clipboard == .unavailable)
        #expect(capabilities.dragAndDrop == .unavailable)
        #expect(capabilities.dragActionNegotiation == .unavailable)
        #expect(capabilities.primarySelection == .unavailable)
        #expect(capabilities.xdgDecoration == .unavailable)
        #expect(capabilities.xdgOutput == .unavailable)
        #expect(capabilities.viewporter == .unavailable)
        #expect(capabilities.presentationTime == .unavailable)
        #expect(capabilities.fractionalScale == .unavailable)
        #expect(capabilities.cursorShape == .unavailable)
        #expect(capabilities.xdgActivation == .unavailable)
        #expect(capabilities.xdgToplevelIcon == .unavailable)
        #expect(capabilities.idleInhibit == .unavailable)
        #expect(capabilities.systemBell == .unavailable)
        #expect(capabilities.pointerWarp == .unavailable)
        #expect(capabilities.relativePointer == .unavailable)
        #expect(capabilities.pointerConstraints == .unavailable)
        #expect(capabilities.textInput == .unavailable)
        #expect(capabilities.linuxDmabuf == .unavailable)
    }

    @Test
    func advertisedProtocolsExposeNegotiatedVersions() {
        let capabilities = WaylandCapabilities.fromAdvertisedProtocols([
            .init(interfaceName: "wl_data_device_manager", advertisedVersion: 7),
            .init(
                interfaceName: "zwp_primary_selection_device_manager_v1",
                advertisedVersion: 1
            ),
            .init(interfaceName: "zxdg_decoration_manager_v1", advertisedVersion: 7),
            .init(interfaceName: "zxdg_output_manager_v1", advertisedVersion: 7),
            .init(interfaceName: "wp_viewporter", advertisedVersion: 4),
            .init(interfaceName: "wp_presentation", advertisedVersion: 4),
            .init(interfaceName: "wp_fractional_scale_manager_v1", advertisedVersion: 3),
            .init(interfaceName: "wp_cursor_shape_manager_v1", advertisedVersion: 9),
            .init(interfaceName: "xdg_activation_v1", advertisedVersion: 3),
            .init(interfaceName: "xdg_toplevel_icon_manager_v1", advertisedVersion: 3),
            .init(interfaceName: "zwp_idle_inhibit_manager_v1", advertisedVersion: 3),
            .init(interfaceName: "xdg_system_bell_v1", advertisedVersion: 3),
            .init(interfaceName: "wp_pointer_warp_v1", advertisedVersion: 4),
            .init(interfaceName: "zwp_relative_pointer_manager_v1", advertisedVersion: 4),
            .init(interfaceName: "zwp_pointer_constraints_v1", advertisedVersion: 4),
            .init(interfaceName: "zwp_text_input_manager_v3", advertisedVersion: 9),
            .init(interfaceName: "zwp_linux_dmabuf_v1", advertisedVersion: 7),
        ])

        #expect(capabilities.clipboard == .available(version: 3))
        #expect(capabilities.dragAndDrop == .available(version: 3))
        #expect(capabilities.dragActionNegotiation == .available(version: 3))
        #expect(capabilities.primarySelection == .available(version: 1))
        #expect(capabilities.xdgDecoration == .available(version: 2))
        #expect(capabilities.xdgOutput == .available(version: 3))
        #expect(capabilities.viewporter == .available(version: 1))
        #expect(capabilities.presentationTime == .available(version: 2))
        #expect(capabilities.fractionalScale == .available(version: 1))
        #expect(capabilities.cursorShape == .available(version: 2))
        #expect(capabilities.xdgActivation == .available(version: 1))
        #expect(capabilities.xdgToplevelIcon == .available(version: 1))
        #expect(capabilities.idleInhibit == .available(version: 1))
        #expect(capabilities.systemBell == .available(version: 1))
        #expect(capabilities.pointerWarp == .available(version: 1))
        #expect(capabilities.relativePointer == .available(version: 1))
        #expect(capabilities.pointerConstraints == .available(version: 1))
        #expect(capabilities.textInput == .available(version: 2))
        #expect(capabilities.linuxDmabuf == .available(version: 5))
    }

    @Test
    func displaySessionCapabilityAssemblyIncludesXDGActivationAndPointerCapture() {
        var requestedInterfaces: [String] = []
        let capabilities = DisplaySession.capabilities { interfaceName in
            requestedInterfaces.append(interfaceName)
            guard
                [
                    "xdg_activation_v1",
                    "xdg_toplevel_icon_manager_v1",
                    "zwp_idle_inhibit_manager_v1",
                    "xdg_system_bell_v1",
                    "wp_pointer_warp_v1",
                    "zwp_relative_pointer_manager_v1",
                    "zwp_pointer_constraints_v1",
                ].contains(interfaceName)
            else {
                return nil
            }

            return AdvertisedWaylandProtocol(
                interfaceName: interfaceName,
                advertisedVersion: 1
            )
        }

        #expect(DisplaySession.capabilityProtocolInterfaceNames.contains("xdg_activation_v1"))
        #expect(
            DisplaySession.capabilityProtocolInterfaceNames.contains(
                "xdg_toplevel_icon_manager_v1"
            )
        )
        #expect(
            DisplaySession.capabilityProtocolInterfaceNames.contains(
                "zwp_idle_inhibit_manager_v1"
            )
        )
        #expect(DisplaySession.capabilityProtocolInterfaceNames.contains("xdg_system_bell_v1"))
        #expect(DisplaySession.capabilityProtocolInterfaceNames.contains("wp_pointer_warp_v1"))
        #expect(
            DisplaySession.capabilityProtocolInterfaceNames.contains(
                "zwp_relative_pointer_manager_v1"
            )
        )
        #expect(
            DisplaySession.capabilityProtocolInterfaceNames.contains(
                "zwp_pointer_constraints_v1"
            )
        )
        #expect(requestedInterfaces == DisplaySession.capabilityProtocolInterfaceNames)
        #expect(capabilities.xdgActivation == .available(version: 1))
        #expect(capabilities.xdgToplevelIcon == .available(version: 1))
        #expect(capabilities.idleInhibit == .available(version: 1))
        #expect(capabilities.systemBell == .available(version: 1))
        #expect(capabilities.pointerWarp == .available(version: 1))
        #expect(capabilities.relativePointer == .available(version: 1))
        #expect(capabilities.pointerConstraints == .available(version: 1))
    }

    @Test
    func exactMinimumAndSupportedVersionsAreAvailable() {
        let capabilities = WaylandCapabilities.fromAdvertisedProtocols([
            .init(interfaceName: "wl_data_device_manager", advertisedVersion: 3),
            .init(
                interfaceName: "zwp_primary_selection_device_manager_v1",
                advertisedVersion: 1
            ),
            .init(interfaceName: "zxdg_decoration_manager_v1", advertisedVersion: 2),
            .init(interfaceName: "zxdg_output_manager_v1", advertisedVersion: 2),
            .init(interfaceName: "wp_viewporter", advertisedVersion: 1),
            .init(interfaceName: "wp_presentation", advertisedVersion: 2),
            .init(interfaceName: "wp_fractional_scale_manager_v1", advertisedVersion: 1),
            .init(interfaceName: "wp_cursor_shape_manager_v1", advertisedVersion: 2),
            .init(interfaceName: "xdg_activation_v1", advertisedVersion: 1),
            .init(interfaceName: "xdg_toplevel_icon_manager_v1", advertisedVersion: 1),
            .init(interfaceName: "zwp_idle_inhibit_manager_v1", advertisedVersion: 1),
            .init(interfaceName: "xdg_system_bell_v1", advertisedVersion: 1),
            .init(interfaceName: "wp_pointer_warp_v1", advertisedVersion: 1),
            .init(interfaceName: "zwp_relative_pointer_manager_v1", advertisedVersion: 1),
            .init(interfaceName: "zwp_pointer_constraints_v1", advertisedVersion: 1),
            .init(interfaceName: "zwp_text_input_manager_v3", advertisedVersion: 2),
            .init(interfaceName: "zwp_linux_dmabuf_v1", advertisedVersion: 5),
        ])

        #expect(capabilities.clipboard == .available(version: 3))
        #expect(capabilities.dragAndDrop == .available(version: 3))
        #expect(capabilities.dragActionNegotiation == .available(version: 3))
        #expect(capabilities.primarySelection == .available(version: 1))
        #expect(capabilities.xdgDecoration == .available(version: 2))
        #expect(capabilities.xdgOutput == .available(version: 2))
        #expect(capabilities.viewporter == .available(version: 1))
        #expect(capabilities.presentationTime == .available(version: 2))
        #expect(capabilities.fractionalScale == .available(version: 1))
        #expect(capabilities.cursorShape == .available(version: 2))
        #expect(capabilities.xdgActivation == .available(version: 1))
        #expect(capabilities.xdgToplevelIcon == .available(version: 1))
        #expect(capabilities.idleInhibit == .available(version: 1))
        #expect(capabilities.systemBell == .available(version: 1))
        #expect(capabilities.pointerWarp == .available(version: 1))
        #expect(capabilities.relativePointer == .available(version: 1))
        #expect(capabilities.pointerConstraints == .available(version: 1))
        #expect(capabilities.textInput == .available(version: 2))
        #expect(capabilities.linuxDmabuf == .available(version: 5))
    }

    @Test
    func versionGatedCapabilitiesRejectTooOldAdvertisements() {
        let capabilities = WaylandCapabilities.fromAdvertisedProtocols([
            .init(interfaceName: "wl_data_device_manager", advertisedVersion: 2),
            .init(interfaceName: "zxdg_decoration_manager_v1", advertisedVersion: 0),
            .init(interfaceName: "zxdg_output_manager_v1", advertisedVersion: 1),
        ])

        #expect(capabilities.clipboard == .available(version: 2))
        #expect(capabilities.dragAndDrop == .available(version: 2))
        #expect(capabilities.dragActionNegotiation == .unavailable)
        #expect(capabilities.xdgDecoration == .unavailable)
        #expect(capabilities.xdgOutput == .unavailable)
    }

    @Test
    func lowerAdvertisedVersionIsPreserved() {
        let capabilities = WaylandCapabilities.fromAdvertisedProtocols([
            .init(interfaceName: "wl_data_device_manager", advertisedVersion: 1)
        ])

        #expect(capabilities.clipboard == .available(version: 1))
        #expect(capabilities.dragAndDrop == .available(version: 1))
        #expect(capabilities.dragActionNegotiation == .unavailable)
    }

    @Test
    func duplicateProtocolAdvertisementsUseHighestVersion() {
        let capabilities = WaylandCapabilities.fromAdvertisedProtocols([
            .init(interfaceName: "zxdg_output_manager_v1", advertisedVersion: 1),
            .init(interfaceName: "zxdg_output_manager_v1", advertisedVersion: 2),
            .init(interfaceName: "zxdg_output_manager_v1", advertisedVersion: 3),
        ])

        #expect(capabilities.xdgOutput == .available(version: 3))
    }

    @Test
    func xdgDecorationVersionOneIsAvailable() {
        let capabilities = WaylandCapabilities.fromAdvertisedProtocols([
            .init(interfaceName: "zxdg_decoration_manager_v1", advertisedVersion: 1)
        ])

        #expect(capabilities.xdgDecoration == .available(version: 1))
    }

    @Test
    func xdgOutputVersionTwoIsAvailableForLogicalGeometryAndMetadata() {
        let capabilities = WaylandCapabilities.fromAdvertisedProtocols([
            .init(interfaceName: "zxdg_output_manager_v1", advertisedVersion: 2)
        ])

        #expect(capabilities.xdgOutput == .available(version: 2))
    }

    @Test
    func xdgOutputBelowMinimumIsUnavailable() {
        let capabilities = WaylandCapabilities.fromAdvertisedProtocols([
            .init(interfaceName: "zxdg_output_manager_v1", advertisedVersion: 1)
        ])

        #expect(capabilities.xdgOutput == .unavailable)
    }

    @Test
    func availabilityReportsBooleanAndVersion() {
        #expect(ProtocolAvailability.unavailable.isAvailable == false)
        #expect(ProtocolAvailability.unavailable.version == nil)
        #expect(ProtocolAvailability.available(version: 2).isAvailable)
        #expect(ProtocolAvailability.available(version: 2).version == 2)
    }
}
