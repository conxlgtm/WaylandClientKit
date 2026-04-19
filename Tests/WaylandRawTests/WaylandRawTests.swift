import Testing

@testable import WaylandRaw

@Suite
struct WaylandRawTests {
    @Test
    func systemWaylandSmokeImportsResolve() {
        WaylandSmokeCheck.verify()
    }

    @Test
    func shimWaylandSmokeImportsResolve() {
        ShimSmokeCheck.verify()
    }
}
