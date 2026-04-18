import Testing

@testable import WaylandRaw

@Suite
struct WaylandRawTests {
    @Test
    func waylandRawBootstrapIsReady() {
        #expect(WaylandRawBootstrap.ready)
    }

    @Test
    func systemWaylandSmokeImportsResolve() {
        WaylandSmokeCheck.verify()
    }

    @Test
    func shimWaylandSmokeImportsResolve() {
        ShimSmokeCheck.verify()
    }
}
