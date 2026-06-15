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
        #expect(capabilities.compositorSessionManagement == .unavailable)
        #expect(capabilities.xdgToplevelIcon == .unavailable)
        #expect(capabilities.xdgDialog == .unavailable)
        #expect(capabilities.xdgToplevelDrag == .unavailable)
        #expect(capabilities.foreignToplevelList == .unavailable)
        #expect(capabilities.idleInhibit == .unavailable)
        #expect(capabilities.systemBell == .unavailable)
        #expect(capabilities.pointerWarp == .unavailable)
        #expect(capabilities.tablet == .unavailable)
        #expect(capabilities.relativePointer == .unavailable)
        #expect(capabilities.pointerConstraints == .unavailable)
        #expect(capabilities.pointerGestures == .unavailable)
        #expect(capabilities.keyboardShortcutsInhibit == .unavailable)
        #expect(capabilities.outputManagement == .unavailable)
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
            .init(interfaceName: "xdg_session_manager_v1", advertisedVersion: 4),
            .init(interfaceName: "xdg_toplevel_icon_manager_v1", advertisedVersion: 3),
            .init(interfaceName: "xdg_wm_dialog_v1", advertisedVersion: 3),
            .init(interfaceName: "xdg_toplevel_drag_manager_v1", advertisedVersion: 3),
            .init(interfaceName: "ext_foreign_toplevel_list_v1", advertisedVersion: 3),
            .init(interfaceName: "zwp_idle_inhibit_manager_v1", advertisedVersion: 3),
            .init(interfaceName: "xdg_system_bell_v1", advertisedVersion: 3),
            .init(interfaceName: "wp_pointer_warp_v1", advertisedVersion: 4),
            .init(interfaceName: "zwp_tablet_manager_v2", advertisedVersion: 9),
            .init(interfaceName: "zwp_relative_pointer_manager_v1", advertisedVersion: 4),
            .init(interfaceName: "zwp_pointer_constraints_v1", advertisedVersion: 4),
            .init(interfaceName: "zwp_pointer_gestures_v1", advertisedVersion: 9),
            .init(
                interfaceName: "zwp_keyboard_shortcuts_inhibit_manager_v1",
                advertisedVersion: 3
            ),
            .init(interfaceName: "zwlr_output_manager_v1", advertisedVersion: 9),
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
        #expect(capabilities.compositorSessionManagement == .available(version: 1))
        #expect(capabilities.xdgToplevelIcon == .available(version: 1))
        #expect(capabilities.xdgDialog == .available(version: 1))
        #expect(capabilities.xdgToplevelDrag == .available(version: 1))
        #expect(capabilities.foreignToplevelList == .available(version: 1))
        #expect(capabilities.idleInhibit == .available(version: 1))
        #expect(capabilities.systemBell == .available(version: 1))
        #expect(capabilities.pointerWarp == .available(version: 1))
        #expect(capabilities.tablet == .available(version: 2))
        #expect(capabilities.relativePointer == .available(version: 1))
        #expect(capabilities.pointerConstraints == .available(version: 1))
        #expect(capabilities.pointerGestures == .available(version: 3))
        #expect(capabilities.keyboardShortcutsInhibit == .available(version: 1))
        #expect(capabilities.outputManagement == .available(version: 4))
        #expect(capabilities.textInput == .available(version: 2))
        #expect(capabilities.linuxDmabuf == .available(version: 5))
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
            .init(interfaceName: "xdg_session_manager_v1", advertisedVersion: 1),
            .init(interfaceName: "xdg_toplevel_icon_manager_v1", advertisedVersion: 1),
            .init(interfaceName: "xdg_wm_dialog_v1", advertisedVersion: 1),
            .init(interfaceName: "xdg_toplevel_drag_manager_v1", advertisedVersion: 1),
            .init(interfaceName: "ext_foreign_toplevel_list_v1", advertisedVersion: 1),
            .init(interfaceName: "zwp_idle_inhibit_manager_v1", advertisedVersion: 1),
            .init(interfaceName: "xdg_system_bell_v1", advertisedVersion: 1),
            .init(interfaceName: "wp_pointer_warp_v1", advertisedVersion: 1),
            .init(interfaceName: "zwp_tablet_manager_v2", advertisedVersion: 2),
            .init(interfaceName: "zwp_relative_pointer_manager_v1", advertisedVersion: 1),
            .init(interfaceName: "zwp_pointer_constraints_v1", advertisedVersion: 1),
            .init(interfaceName: "zwp_pointer_gestures_v1", advertisedVersion: 3),
            .init(
                interfaceName: "zwp_keyboard_shortcuts_inhibit_manager_v1",
                advertisedVersion: 1
            ),
            .init(interfaceName: "zwlr_output_manager_v1", advertisedVersion: 4),
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
        #expect(capabilities.compositorSessionManagement == .available(version: 1))
        #expect(capabilities.xdgToplevelIcon == .available(version: 1))
        #expect(capabilities.xdgDialog == .available(version: 1))
        #expect(capabilities.xdgToplevelDrag == .available(version: 1))
        #expect(capabilities.foreignToplevelList == .available(version: 1))
        #expect(capabilities.idleInhibit == .available(version: 1))
        #expect(capabilities.systemBell == .available(version: 1))
        #expect(capabilities.pointerWarp == .available(version: 1))
        #expect(capabilities.tablet == .available(version: 2))
        #expect(capabilities.relativePointer == .available(version: 1))
        #expect(capabilities.pointerConstraints == .available(version: 1))
        #expect(capabilities.pointerGestures == .available(version: 3))
        #expect(capabilities.keyboardShortcutsInhibit == .available(version: 1))
        #expect(capabilities.outputManagement == .available(version: 4))
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
