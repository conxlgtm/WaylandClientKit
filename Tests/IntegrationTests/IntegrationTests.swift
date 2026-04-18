import Testing
import WaylandClient

@Suite
struct IntegrationTests {
    @Test
    func integrationPlaceholderBuilds() {
        #expect(WaylandClientBootstrap.ready)
    }
}
