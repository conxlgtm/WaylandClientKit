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
        #expect(SupportedVersions.wlSeat == RawVersion(9))
    }
}
