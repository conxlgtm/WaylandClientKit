import Foundation
import Glibc
import Testing
import WaylandClient
import WaylandGraphicsPreview

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

    @Test
    func liveGraphicsFactsProjectWithoutRequiringGpuHardware() async throws {
        try await WaylandDisplay.withConnection(
            discoveryTimeoutMilliseconds: 5_000
        ) { display in
            let capabilities = try await display.graphicsSurfaceCapabilities()
            let runtimePath = try await display.graphicsRuntimePath()
            let decision = try await display.graphicsBackingDecision()
            let forcedSoftwarePath = try await display.graphicsRuntimePath(
                policy: .forceSoftware
            )

            #expect(runtimePath.capabilities == capabilities)
            #expect(forcedSoftwarePath.backing == .fallback(.forcedSoftware))
            #expect(forcedSoftwarePath.fallback == .forcedSoftware)

            switch capabilities.dmabuf {
            case .unavailable, .pending:
                #expect(runtimePath.backing == .fallback(.dmabufUnavailable))
                #expect(runtimePath.dmabuf == .fallback(.dmabufUnavailable))
                #expect(decision == .software(.dmabufUnavailable))
            case .available:
                #expect(runtimePath.backing == .advertised)
                #expect(runtimePath.dmabuf == .advertised)
                if case .gpu(let projectedPath) = decision {
                    #expect(projectedPath.capabilities == capabilities)
                } else {
                    Issue.record("dmabuf availability should project a GPU decision")
                }
            }
        }
    }

    @Test
    func optionalRenderNodeFactIsReportedWithoutFailingHeadlessRuns() {
        guard let path = firstRenderNodePath() else {
            Issue.record(
                "Skipping optional GPU validation: no accessible DRM render node.",
                severity: .warning
            )
            return
        }

        #expect(path.hasPrefix("/dev/dri/renderD"))
    }

    @Test
    func managedPreviewBackingSubmitsClearFrameThroughSoftwareFallback() async throws {
        try await WaylandDisplay.withConnection(
            discoveryTimeoutMilliseconds: 5_000
        ) { display in
            let backing = try await display.createGraphicsWindowBacking(
                windowConfiguration: WindowConfiguration(
                    title: "SwiftWayland Graphics Preview Test",
                    appID: "swift-wayland-graphics-preview-test",
                    initialWidth: 32,
                    initialHeight: 32
                ),
                graphicsConfiguration: WaylandGraphicsConfiguration(
                    fallbackPolicy: .forceSoftware
                )
            )
            let lease = try await backing.nextFrame()
            try await lease.submit(
                .clearColor(WaylandGraphicsXRGBColor(red: 0, green: 0, blue: 0))
            )
            let runtimePath = try await backing.runtimePath
            try await backing.close()

            #expect(runtimePath.backing == .fallback(.forcedSoftware))
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

private func firstRenderNodePath() -> String? {
    for index in 128..<192 {
        let path = "/dev/dri/renderD\(index)"
        let isAccessible = unsafe path.withCString { pathPointer in
            unsafe Glibc.access(pathPointer, R_OK | W_OK)
        }
        if isAccessible == 0 {
            return path
        }
    }

    return nil
}
