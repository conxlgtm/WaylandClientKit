import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum SubsurfaceSmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            log("feature: subsurface")
            log("capability: wl_subcompositor required")
            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Subsurface Smoke",
                    appID: "wayland-client-kit-subsurface-smoke",
                    initialWidth: 360,
                    initialHeight: 240,
                    closeRequestPolicy: .requestOnly
                )
            )
            try await window.show(drawParent)
            log("operation: show-parent pass")

            let child = try await window.createSubsurface(
                configuration: try SubsurfaceConfiguration(
                    position: LogicalOffset(x: 48, y: 56),
                    size: PositiveLogicalSize(width: 120, height: 80),
                    synchronizationMode: .desynchronized
                )
            )
            try await child.show(drawChild)
            log("operation: create-subsurface pass mode=desynchronized")
            log("created \(child.identity) at \(try await child.geometry)")

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await consumeDisplayEvents(display.events, window: window) }
                group.addTask { try await animate(child: child) }
                if let autoCloseSeconds = options.autoCloseSeconds {
                    group.addTask {
                        try await Task.sleep(for: .seconds(autoCloseSeconds))
                        await window.close()
                    }
                }

                _ = try await group.next()
                group.cancelAll()
            }
            log("result: pass")
            log("cleanup: pass")
        }
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        window: Window
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .windowCloseRequested(let windowID) where windowID == window.id:
                await window.close()
            case .windowClosed(let windowID) where windowID == window.id:
                return
            case .diagnostic(let diagnostic):
                log("display diagnostic \(diagnostic)")
            default:
                break
            }
        }
    }

    nonisolated private static func animate(child: Subsurface) async throws {
        var phase = 0
        while !Task.isCancelled {
            try await Task.sleep(for: .milliseconds(220))
            guard try await !child.isClosed else { return }

            let x = Int32(48 + (phase % 6) * 24)
            let y = Int32(56 + ((phase / 6) % 3) * 18)
            try await child.setPosition(LogicalOffset(x: x, y: y))
            do {
                try await child.redraw(drawChild)
                log("operation: move-and-redraw pass")
            } catch let error as ClientError where isFrameCallbackPending(error) {
                try await child.requestRedraw()
                log("operation: move-and-redraw blocked(frameCallbackOutstanding)")
            }
            log("moved \(child.identity) to x=\(x) y=\(y)")
            phase += 1
        }
    }

    nonisolated private static func isFrameCallbackPending(_ error: ClientError) -> Bool {
        guard case .display(.subsurfacePresentationFailed(let failure)) = error else {
            return false
        }

        guard case .presentation(.frameCallbackRequest(let detail)) = failure.cause else {
            return false
        }

        return detail.contains("frame callback")
    }

    nonisolated private static func drawParent(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let stripe = ((x / 24) + (row / 24)).isMultiple(of: 2)
                unsafe pixels[unchecked: x] = stripe ? 0x0028_3030 : 0x0018_2020
            }
        }
    }

    nonisolated private static func drawChild(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let border =
                    row < 4 || x < 4 || row >= Int(frame.height) - 4
                    || x >= Int(frame.width) - 4
                unsafe pixels[unchecked: x] = border ? 0x00FF_D060 : 0x0040_A0E0
            }
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[SubsurfaceSmoke] \(message)")
    }
}
