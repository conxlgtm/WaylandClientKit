import Testing

@testable import WaylandRaw

@Suite
struct VersionNegotiationTests {
    @Test
    func choosesClientVersionWhenServerOffersMore() throws {
        let global = try #require(
            RawGlobalAdvertisement(
                name: 8,
                interfaceName: "xdg_wm_base",
                advertisedVersion: 7
            )
        )
        #expect(global.negotiatedVersion(supportedByClient: 6) == RawVersion(6))
    }
    @Test
    func choosesServerVersionWhenClientSupportsMore() throws {
        let global = try #require(
            RawGlobalAdvertisement(
                name: 8,
                interfaceName: "xdg_wm_base",
                advertisedVersion: 4
            )
        )
        #expect(global.negotiatedVersion(supportedByClient: 6) == RawVersion(4))
    }
    @Test
    func choosesEqualVersionWhenBothMatch() throws {
        let global = try #require(
            RawGlobalAdvertisement(
                name: 5,
                interfaceName: "wl_compositor",
                advertisedVersion: 6
            )
        )
        #expect(global.negotiatedVersion(supportedByClient: 6) == RawVersion(6))
    }
    @Test
    func version1AlwaysNegotiatesToOne() throws {
        let global = try #require(
            RawGlobalAdvertisement(
                name: 2,
                interfaceName: "wl_shm",
                advertisedVersion: 1
            )
        )
        #expect(global.negotiatedVersion(supportedByClient: 1) == RawVersion(1))
    }
    @Test
    func supportedVersionsTableHasExpectedValues() {
        #expect(SupportedVersions.wlCompositor == RawVersion(6))
        #expect(SupportedVersions.wlShm == RawVersion(1))
        #expect(SupportedVersions.xdgWmBase == RawVersion(7))
        #expect(SupportedVersions.zxdgDecorationManagerV1Minimum == RawVersion(1))
        #expect(SupportedVersions.zxdgDecorationManagerV1 == RawVersion(2))
        #expect(SupportedVersions.zxdgOutputManagerV1Minimum == RawVersion(2))
        #expect(SupportedVersions.zxdgOutputManagerV1 == RawVersion(3))
        #expect(SupportedVersions.wpViewporter == RawVersion(1))
        #expect(SupportedVersions.wpFractionalScaleManagerV1 == RawVersion(1))
        #expect(SupportedVersions.wlDataDeviceManager == RawVersion(3))
        #expect(SupportedVersions.wlSeat == RawVersion(10))
    }
    @Test
    func xdgDecorationManagerV1IsBoundForPreInitialConfigureCreation() throws {
        let v1Global = try #require(
            RawGlobalAdvertisement(
                name: 1,
                interfaceName: "zxdg_decoration_manager_v1",
                advertisedVersion: 1
            )
        )
        let v2Global = try #require(
            RawGlobalAdvertisement(
                name: 2,
                interfaceName: "zxdg_decoration_manager_v1",
                advertisedVersion: 2
            )
        )
        let v3Global = try #require(
            RawGlobalAdvertisement(
                name: 3,
                interfaceName: "zxdg_decoration_manager_v1",
                advertisedVersion: 3
            )
        )
        #expect(
            OptionalGlobalDescriptors.zxdgDecorationManagerV1.bindingDecision(for: v1Global)
                == .bind(version: RawVersion(1))
        )
        #expect(
            OptionalGlobalDescriptors.zxdgDecorationManagerV1.bindingDecision(for: v2Global)
                == .bind(version: RawVersion(2))
        )
        #expect(
            OptionalGlobalDescriptors.zxdgDecorationManagerV1.bindingDecision(for: v3Global)
                == .bind(version: RawVersion(2))
        )
    }

    @Test
    func xdgOutputManagerV2IsBoundForLogicalGeometryAndMetadata() throws {
        let v1Global = try #require(
            RawGlobalAdvertisement(
                name: 1,
                interfaceName: "zxdg_output_manager_v1",
                advertisedVersion: 1
            )
        )
        let v2Global = try #require(
            RawGlobalAdvertisement(
                name: 2,
                interfaceName: "zxdg_output_manager_v1",
                advertisedVersion: 2
            )
        )
        let v3Global = try #require(
            RawGlobalAdvertisement(
                name: 3,
                interfaceName: "zxdg_output_manager_v1",
                advertisedVersion: 3
            )
        )
        #expect(
            OptionalGlobalDescriptors.zxdgOutputManagerV1.bindingDecision(for: v1Global)
                == .unsupportedVersion(
                    advertised: RawVersion(1),
                    minimum: RawVersion(2)
                )
        )
        #expect(
            OptionalGlobalDescriptors.zxdgOutputManagerV1.bindingDecision(for: v2Global)
                == .bind(version: RawVersion(2))
        )
        #expect(
            OptionalGlobalDescriptors.zxdgOutputManagerV1.bindingDecision(for: v3Global)
                == .bind(version: RawVersion(3))
        )
    }
}
