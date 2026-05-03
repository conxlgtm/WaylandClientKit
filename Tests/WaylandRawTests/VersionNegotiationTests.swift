import Testing

@testable import WaylandRaw

@Suite
struct VersionNegotiationTests {
    @Test
    func choosesClientVersionWhenServerOffersMore() {
        let global = RawGlobalAdvertisement(
            name: 8,
            interfaceName: "xdg_wm_base",
            advertisedVersion: 7
        )
        #expect(global.negotiatedVersion(supportedByClient: 6) == RawVersion(6))
    }

    @Test
    func choosesServerVersionWhenClientSupportsMore() {
        let global = RawGlobalAdvertisement(
            name: 8,
            interfaceName: "xdg_wm_base",
            advertisedVersion: 4
        )
        #expect(global.negotiatedVersion(supportedByClient: 6) == RawVersion(4))
    }

    @Test
    func choosesEqualVersionWhenBothMatch() {
        let global = RawGlobalAdvertisement(
            name: 5,
            interfaceName: "wl_compositor",
            advertisedVersion: 6
        )
        #expect(global.negotiatedVersion(supportedByClient: 6) == RawVersion(6))
    }

    @Test
    func version1AlwaysNegotiatesToOne() {
        let global = RawGlobalAdvertisement(
            name: 2,
            interfaceName: "wl_shm",
            advertisedVersion: 1
        )
        #expect(global.negotiatedVersion(supportedByClient: 1) == RawVersion(1))
    }

    @Test
    func supportedVersionsTableHasExpectedValues() {
        #expect(SupportedVersions.wlCompositor == RawVersion(6))
        #expect(SupportedVersions.wlShm == RawVersion(1))
        #expect(SupportedVersions.xdgWmBase == RawVersion(7))
        #expect(SupportedVersions.zxdgDecorationManagerV1Minimum == RawVersion(2))
        #expect(SupportedVersions.zxdgDecorationManagerV1 == RawVersion(2))
        #expect(SupportedVersions.wlSeat == RawVersion(10))
    }

    @Test
    func xdgDecorationManagerV1IsNotBoundUntilFirstConfigureGatingExists() {
        let v1Global = RawGlobalAdvertisement(
            name: 1,
            interfaceName: "zxdg_decoration_manager_v1",
            advertisedVersion: 1
        )
        let v2Global = RawGlobalAdvertisement(
            name: 2,
            interfaceName: "zxdg_decoration_manager_v1",
            advertisedVersion: 2
        )
        let v3Global = RawGlobalAdvertisement(
            name: 3,
            interfaceName: "zxdg_decoration_manager_v1",
            advertisedVersion: 3
        )

        #expect(!RawDisplayConnection.shouldBindXDGDecorationManager(v1Global))
        #expect(RawDisplayConnection.shouldBindXDGDecorationManager(v2Global))
        #expect(RawDisplayConnection.shouldBindXDGDecorationManager(v3Global))
        #expect(
            RawDisplayConnection.xdgDecorationManagerBindingDecision(v1Global)
                == .unsupportedVersion(
                    advertised: RawVersion(1),
                    minimum: RawVersion(2)
                )
        )
        #expect(
            RawDisplayConnection.xdgDecorationManagerBindingDecision(v2Global)
                == .bind(version: RawVersion(2))
        )
        #expect(
            v3Global.negotiatedVersion(
                supportedByClient: SupportedVersions.zxdgDecorationManagerV1
            )
                == RawVersion(2)
        )
    }
}
