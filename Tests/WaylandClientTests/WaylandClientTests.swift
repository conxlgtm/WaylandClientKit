import Testing
import WaylandClient

@Suite
struct WaylandClientTests {
    @Test
    func waylandClientBootstrapIsReady() {
        #expect(WaylandClientBootstrap.ready)
    }
}
