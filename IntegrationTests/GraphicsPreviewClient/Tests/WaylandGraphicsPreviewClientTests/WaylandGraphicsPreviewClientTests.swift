import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsPreviewClientTests {
    @Test
    func graphicsPreviewTypesCompileForExternalClients() throws {
        let clientCapabilities = WaylandCapabilities(
            clipboard: .unavailable,
            dragAndDrop: .unavailable,
            dragActionNegotiation: .unavailable,
            primarySelection: .unavailable,
            xdgDecoration: .unavailable,
            xdgOutput: .unavailable,
            viewporter: .unavailable,
            presentationTime: .available(version: 1),
            fractionalScale: .unavailable,
            cursorShape: .unavailable,
            textInput: .unavailable,
            linuxDmabuf: .unavailable
        )

        let capabilities = WaylandGraphicsSurfaceCapabilities(
            capabilities: clientCapabilities
        )
        let path = WaylandGraphicsRuntimePath.projected(
            capabilities: capabilities,
            policy: .preferGPUFallbackToSoftware
        )
        let decision = WaylandGraphicsFallbackPolicy.requireGPU.decide(
            capabilities: capabilities
        )

        #expect(path.backing == .fallback(.dmabufUnavailable))
        #expect(decision == .unavailable(.dmabufUnavailable))
    }

    @Test
    func displayGraphicsPreviewMethodsAreAvailableToExternalClients() async throws {
        func acceptsDisplay(_ display: WaylandDisplay) async throws {
            _ = try await display.graphicsSurfaceCapabilities()
            _ = try await display.graphicsRuntimePath(policy: .forceSoftware)
            _ = try await display.graphicsBackingDecision(policy: .requireGPU)
        }

        _ = acceptsDisplay
    }
}
