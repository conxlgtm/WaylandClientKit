import Foundation
import Glibc
import WaylandClient
import WaylandGraphicsPreview

@main
enum GraphicsPreviewManagedGPUClear {
    static func main() async {
        let result: ManagedGPUClearReport
        let exitCode: Int32
        do {
            result = try await run()
            exitCode = EXIT_SUCCESS
        } catch {
            result = ManagedGPUClearReport(failure: "\(error)")
            exitCode = EXIT_FAILURE
        }

        ManagedGPUClearReportFormatter(report: result).write()
        guard exitCode == EXIT_SUCCESS else {
            exit(exitCode)
        }
    }

    private static func run() async throws -> ManagedGPUClearReport {
        try await WaylandDisplay.withConnection { display in
            try await managedClearReport(on: display)
        }
    }

    nonisolated private static func managedClearReport(
        on display: WaylandDisplay
    ) async throws -> ManagedGPUClearReport {
        let capabilities = try await display.graphicsSurfaceCapabilities()
        let backing = try await display.createGraphicsWindowBacking(
            windowConfiguration: WindowConfiguration(
                title: "SwiftWayland Managed GPU Clear",
                appID: "swift-wayland-managed-gpu-clear",
                initialWidth: 96,
                initialHeight: 96,
                bufferCount: 2
            ),
            graphicsConfiguration: WaylandGraphicsConfiguration(
                backingPreference: .managedGPU,
                presentationFeedbackPolicy: .requestWhenAvailable
            )
        )

        let lease = try await backing.nextFrame()
        let frameResult = try await lease.submit(
            .clearColor(
                WaylandGraphicsClearFrame(
                    color: WaylandGraphicsXRGBColor(red: 0x18, green: 0xB8, blue: 0x92)
                )
            )
        )
        try await backing.close()

        return ManagedGPUClearReport(
            capabilities: capabilities,
            runtimePath: frameResult.runtimePath,
            frameResult: frameResult
        )
    }
}

private struct ManagedGPUClearReport: Sendable {
    var capabilities: WaylandGraphicsSurfaceCapabilities?
    var runtimePath: WaylandGraphicsRuntimePath?
    var frameResult: WaylandGraphicsFrameResult?
    var failure: String?

    nonisolated init(
        capabilities reportedCapabilities: WaylandGraphicsSurfaceCapabilities? = nil,
        runtimePath reportedRuntimePath: WaylandGraphicsRuntimePath? = nil,
        frameResult reportedFrameResult: WaylandGraphicsFrameResult? = nil,
        failure reportedFailure: String? = nil
    ) {
        capabilities = reportedCapabilities
        runtimePath = reportedRuntimePath
        frameResult = reportedFrameResult
        failure = reportedFailure
    }
}

private struct ManagedGPUClearReportFormatter {
    let report: ManagedGPUClearReport

    func write() {
        let output = lines().joined(separator: "\n") + "\n"
        FileHandle.standardOutput.write(Data(output.utf8))
    }

    private func lines() -> [String] {
        guard let capabilities = report.capabilities,
            let runtimePath = report.runtimePath,
            let frameResult = report.frameResult
        else {
            return [
                "SwiftWayland Managed GPU Clear",
                "display: \(displayName())",
                "compositor: \(compositorName())",
                "failure: \(report.failure ?? "none")",
            ]
        }

        return [
            "SwiftWayland Managed GPU Clear",
            "display: \(displayName())",
            "compositor: \(compositorName())",
            "dmabuf: \(availability(capabilities.dmabuf))",
            "presentation feedback: \(availability(capabilities.presentationFeedback))",
            "requested backing: managedGPU",
            "runtime backing: \(status(runtimePath.backing))",
            "runtime dmabuf: \(status(runtimePath.dmabuf))",
            "runtime gbm: \(status(runtimePath.gbm))",
            "runtime egl: \(status(runtimePath.egl))",
            "frame operation: \(frameResult.operation)",
            "frame size: \(frameResult.size.width)x\(frameResult.size.height)",
            "frame backing: \(status(frameResult.backing))",
            "presentation feedback requested: \(frameResult.presentationFeedbackRequested)",
            "fallback reason: \(runtimePath.fallback.map(String.init(describing:)) ?? "none")",
            "failure: \(report.failure ?? "none")",
        ]
    }

    private func displayName() -> String {
        ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] ?? "unset"
    }

    private func compositorName() -> String {
        let environment = ProcessInfo.processInfo.environment
        let desktop = environment["XDG_CURRENT_DESKTOP"]
        let session = environment["DESKTOP_SESSION"]

        switch (desktop, session) {
        case (.some(let desktopName), .some(let sessionName)):
            return "\(desktopName) / \(sessionName)"
        case (.some(let desktopName), .none):
            return desktopName
        case (.none, .some(let sessionName)):
            return sessionName
        case (.none, .none):
            return "unknown"
        }
    }

    private func availability(
        _ availability: WaylandGraphicsProtocolAvailability
    ) -> String {
        switch availability {
        case .unavailable:
            "unavailable"
        case .pending(let version):
            "pending v\(version)"
        case .available(let version):
            "advertised v\(version)"
        }
    }

    private func status(_ status: WaylandGraphicsRuntimeStatus) -> String {
        switch status {
        case .unavailable:
            "unavailable"
        case .pending:
            "pending"
        case .advertised:
            "advertised"
        case .configured:
            "configured"
        case .active:
            "active"
        case .failed(let reason):
            "failed(\(reason))"
        case .fallback(let reason):
            "fallback(\(reason))"
        }
    }
}
