import Testing

@testable import WaylandClient

@Suite
struct WaylandSessionCapabilityAssemblyTests {
    @Test
    func sessionCapabilitiesIncludeOptionalProtocols() {
        var requestedInterfaces: [String] = []
        let capabilities = DisplaySession.capabilities { interfaceName in
            requestedInterfaces.append(interfaceName)
            guard advertisedInterfaces.contains(interfaceName) else {
                return nil
            }
            return AdvertisedWaylandProtocol(
                interfaceName: interfaceName,
                advertisedVersion: 1
            )
        }

        #expect(requestedInterfaces == DisplaySession.capabilityProtocolInterfaceNames)
        #expect(capabilities.xdgActivation == .available(version: 1))
        #expect(capabilities.compositorSessionManagement == .available(version: 1))
        #expect(capabilities.xdgToplevelIcon == .available(version: 1))
        #expect(capabilities.xdgDialog == .available(version: 1))
        #expect(capabilities.xdgToplevelDrag == .available(version: 1))
        #expect(capabilities.foreignToplevelList == .available(version: 1))
        #expect(capabilities.idleInhibit == .available(version: 1))
        #expect(capabilities.systemBell == .available(version: 1))
        #expect(capabilities.pointerWarp == .available(version: 1))
        #expect(capabilities.tablet == .available(version: 1))
        #expect(capabilities.relativePointer == .available(version: 1))
        #expect(capabilities.pointerConstraints == .available(version: 1))
        #expect(capabilities.pointerGestures == .available(version: 1))
        #expect(capabilities.keyboardShortcutsInhibit == .available(version: 1))
        #expect(capabilities.outputManagement == .available(version: 1))
    }

    private let advertisedInterfaces: Set<String> = [
        "xdg_activation_v1",
        "xdg_session_manager_v1",
        "xdg_toplevel_icon_manager_v1",
        "xdg_wm_dialog_v1",
        "xdg_toplevel_drag_manager_v1",
        "ext_foreign_toplevel_list_v1",
        "zwp_idle_inhibit_manager_v1",
        "xdg_system_bell_v1",
        "wp_pointer_warp_v1",
        "zwp_tablet_manager_v2",
        "zwp_relative_pointer_manager_v1",
        "zwp_pointer_constraints_v1",
        "zwp_pointer_gestures_v1",
        "zwp_keyboard_shortcuts_inhibit_manager_v1",
        "zwlr_output_manager_v1",
    ]
}
