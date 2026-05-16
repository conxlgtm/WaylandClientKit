import Foundation
import Testing
import WaylandClient

@Suite(
    "GPU preview live capability",
    .enabled(
        if: GPUPreviewLiveEnvironment.isEnabled,
        "Set WAYLAND_DISPLAY and SWIFT_WAYLAND_ENABLE_GPU_PREVIEW_TESTS=1"
    ),
    .serialized
)
struct GPUPreviewLiveCapabilityTests {
    @Test
    func connectionReportsDmabufCapabilityForGpuPreview() async throws {
        try await WaylandDisplay.withConnection(
            discoveryTimeoutMilliseconds: 5_000
        ) { display in
            let capabilities = try await display.capabilities()

            guard capabilities.linuxDmabuf.isAvailable else {
                Issue.record(
                    """
                    Skipping GPU preview live test: compositor did not advertise \
                    zwp_linux_dmabuf_v1.
                    """,
                    severity: .warning
                )
                return
            }

            #expect(capabilities.linuxDmabuf.version != nil)
        }
    }
}

private enum GPUPreviewLiveEnvironment {
    static var isEnabled: Bool {
        environmentValue("SWIFT_WAYLAND_ENABLE_GPU_PREVIEW_TESTS") == "1"
            && environmentValue("WAYLAND_DISPLAY") != nil
    }

    private static func environmentValue(_ key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key],
            !value.isEmpty
        else {
            return nil
        }

        return value
    }
}
