import Foundation
import Glibc
import WaylandClient
import WaylandGraphicsPreview

@main
enum GPUPreviewSmokeClient {
    static func main() async {
        let report: GPUPreviewSmokeReport
        let exitCode: Int32
        do {
            report = try await WaylandDisplay.withConnection { display in
                var report = GPUPreviewSmokeReport()
                let backing = try await display.createGraphicsWindowBacking(
                    windowConfiguration: WindowConfiguration(
                        title: "SwiftWayland Graphics Preview",
                        appID: "swift-wayland-graphics-preview",
                        initialWidth: 96,
                        initialHeight: 96,
                        bufferCount: 2
                    )
                )
                report.windowCreation = "success"

                let lease = try await backing.nextFrame()
                let result = try await lease.submit(
                    .clearColor(
                        WaylandGraphicsXRGBColor(red: 0x3F, green: 0x80, blue: 0xFF)
                    )
                )
                let operation = GPUPreviewSmokeReport.operation(result.operation)
                report.submittedFrame = "success \(operation)"
                report.frameSize = "\(result.size.width)x\(result.size.height)"
                report.runtimePath = result.runtimePath
                report.releaseReuse = GPUPreviewSmokeReport.releaseReuseStatus(
                    result.runtimePath
                )

                try await backing.close()
                return report
            }
            exitCode = EXIT_SUCCESS
        } catch {
            report = GPUPreviewSmokeReport(failure: "\(error)")
            exitCode = EXIT_FAILURE
        }

        GPUPreviewSmokeReportFormatter(report: report).write()
        guard exitCode == EXIT_SUCCESS else {
            exit(exitCode)
        }
    }
}

private struct GPUPreviewSmokeReportFormatter {
    let report: GPUPreviewSmokeReport

    func write() {
        FileHandle.standardOutput.write(Data((lines().joined(separator: "\n") + "\n").utf8))
    }

    private func lines() -> [String] {
        guard let runtimePath = report.runtimePath else {
            return [
                "SwiftWayland GPU Preview Runtime Path",
                "display: \(displayName())",
                "compositor: \(compositorName())",
                "window creation: \(report.windowCreation)",
                "submitted frame: \(report.submittedFrame)",
                "failure: \(report.failure ?? "none")",
            ]
        }

        let capabilities = runtimePath.capabilities
        return [
            "SwiftWayland GPU Preview Runtime Path",
            "display: \(displayName())",
            "compositor: \(compositorName())",
            "window creation: \(report.windowCreation)",
            "dmabuf advertised version: \(availability(capabilities.dmabuf))",
            "surface dmabuf feedback: \(surfaceFeedbackStatus(runtimePath))",
            "selected device: \(selectedDevice(runtimePath))",
            "selected format/modifier: \(selectedFormat(runtimePath))",
            "gbm device: \(status(runtimePath.gbm))",
            "gbm buffer allocation: \(bufferAllocation(runtimePath))",
            "egl display/context: \(status(runtimePath.egl))",
            "egl clear/render: \(renderStatus(runtimePath))",
            "dmabuf import: \(status(runtimePath.dmabuf))",
            "explicit sync: \(explicitSyncStatus(runtimePath))",
            "fifo: \(status(runtimePath.pacing.fifo))",
            "commit timing: \(status(runtimePath.pacing.commitTiming))",
            "metadata content type: \(status(runtimePath.metadata.contentType))",
            "metadata alpha modifier: \(status(runtimePath.metadata.alphaModifier))",
            "metadata tearing control: \(status(runtimePath.metadata.tearingControl))",
            """
            metadata color representation: \
            \(status(runtimePath.metadata.colorRepresentation))
            """,
            "metadata color management: \(status(runtimePath.metadata.colorManagement))",
            "presentation feedback: \(status(runtimePath.presentationFeedback))",
            "submitted frame: \(report.submittedFrame)",
            "frame size: \(report.frameSize)",
            "release/reuse: \(report.releaseReuse)",
            "backing: \(backing(runtimePath))",
            "fallback reason: \(fallbackReason(runtimePath))",
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

    private func surfaceFeedbackStatus(
        _ path: WaylandGraphicsRuntimePath
    ) -> String {
        switch path.dmabuf {
        case .active, .configured:
            "usable"
        case .advertised:
            "not configured"
        case .fallback(let reason):
            "fallback(\(reason))"
        case .failed(let reason):
            "failed(\(reason))"
        case .pending:
            "pending"
        case .unavailable:
            "unavailable"
        }
    }

    private func selectedDevice(
        _ path: WaylandGraphicsRuntimePath
    ) -> String {
        switch path.gbm {
        case .active, .configured:
            "selected by managed GPU path"
        case .fallback(let reason):
            "not selected, fallback(\(reason))"
        case .failed(let reason):
            "failed(\(reason))"
        case .unavailable:
            "not selected"
        case .advertised, .pending:
            status(path.gbm)
        }
    }

    private func selectedFormat(
        _ path: WaylandGraphicsRuntimePath
    ) -> String {
        switch path.backing {
        case .active, .configured:
            "selected by managed GPU path"
        case .fallback(let reason):
            "not selected, fallback(\(reason))"
        case .failed(let reason):
            "failed(\(reason))"
        case .advertised:
            "not selected"
        case .pending:
            "pending"
        case .unavailable:
            "unavailable"
        }
    }

    private func bufferAllocation(
        _ path: WaylandGraphicsRuntimePath
    ) -> String {
        switch path.gbm {
        case .active:
            "active"
        case .configured:
            "configured"
        case .fallback(let reason):
            "not allocated, fallback(\(reason))"
        case .failed(let reason):
            "failed(\(reason))"
        case .advertised, .pending, .unavailable:
            status(path.gbm)
        }
    }

    private func renderStatus(
        _ path: WaylandGraphicsRuntimePath
    ) -> String {
        switch path.egl {
        case .active:
            "active"
        case .configured:
            "configured"
        case .fallback(let reason):
            "not rendered, fallback(\(reason))"
        case .failed(let reason):
            "failed(\(reason))"
        case .advertised, .pending, .unavailable:
            status(path.egl)
        }
    }

    private func explicitSyncStatus(
        _ path: WaylandGraphicsRuntimePath
    ) -> String {
        "\(availability(path.capabilities.explicitSync)), runtime \(status(path.explicitSync))"
    }

    private func status(
        _ status: WaylandGraphicsRuntimeStatus
    ) -> String {
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

    private func backing(_ path: WaylandGraphicsRuntimePath) -> String {
        switch path.backing {
        case .active:
            "gpu active"
        case .configured:
            "gpu configured"
        case .advertised:
            "gpu projected"
        case .fallback(let reason):
            "software fallback(\(reason))"
        case .failed(let reason):
            "unavailable(\(reason))"
        case .pending:
            "pending"
        case .unavailable:
            "unavailable"
        }
    }

    private func fallbackReason(
        _ path: WaylandGraphicsRuntimePath
    ) -> String {
        path.fallback.map(String.init(describing:)) ?? "none"
    }
}

private struct GPUPreviewSmokeReport {
    var runtimePath: WaylandGraphicsRuntimePath?
    var windowCreation = "not attempted"
    var submittedFrame = "not attempted"
    var frameSize = "unknown"
    var releaseReuse = "not observed"
    var failure: String?

    nonisolated static func operation(
        _ operation: WaylandGraphicsSubmissionOperation
    ) -> String {
        switch operation {
        case .show:
            "show"
        case .redraw:
            "redraw"
        }
    }

    nonisolated static func releaseReuseStatus(
        _ path: WaylandGraphicsRuntimePath
    ) -> String {
        switch path.backing {
        case .active, .configured:
            "managed by GPU buffer lifecycle"
        case .fallback:
            "not observed, software fallback"
        case .failed(let reason):
            "not observed, failed(\(reason))"
        case .advertised:
            "not observed"
        case .pending:
            "pending"
        case .unavailable:
            "unavailable"
        }
    }
}
