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
        #expect(capabilities.linuxDmabuf == .available(version: 5))
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
    func xdgDecorationBelowMinimumIsUnavailable() {
        let capabilities = WaylandCapabilities.fromAdvertisedProtocols([
            .init(interfaceName: "zxdg_decoration_manager_v1", advertisedVersion: 1)
        ])

        #expect(capabilities.xdgDecoration == .unavailable)
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
