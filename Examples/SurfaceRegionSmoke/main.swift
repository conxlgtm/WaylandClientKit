import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum SurfaceRegionSmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 128,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "SwiftWayland Surface Region Smoke",
                    appID: "swift-wayland-surface-region-smoke",
                    initialWidth: 420,
                    initialHeight: 260,
                    closeRequestPolicy: .requestOnly
                )
            )

            try await window.show { frame in
                draw(frame, restricted: true)
            }

            let activeRegion = try centerRegion(for: try await window.geometry)
            try await window.setInputRegion(activeRegion)
            try await window.setOpaqueRegion(activeRegion)
            log("input and opaque regions set to \(activeRegion.rectangles)")
            log(
                "clicks outside the marked center should miss this window if the compositor honors input regions"
            )
            log("clicks inside the center region should still emit pointer/button events below")

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await consumeDisplayEvents(display.events, window: window) }
                group.addTask { try await consumeInputEvents(display.inputEvents, window: window) }
                group.addTask { try await resetRegions(after: 5, window: window) }
                if let autoCloseSeconds = options.autoCloseSeconds {
                    group.addTask {
                        try await Task.sleep(for: .seconds(autoCloseSeconds))
                        await window.close()
                    }
                }

                _ = try await group.next()
                group.cancelAll()
            }
        }
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        window: Window
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == window.id:
                try await window.redraw { frame in
                    draw(frame, restricted: false)
                }
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

    nonisolated private static func consumeInputEvents(
        _ events: InputEvents,
        window: Window
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard event.windowID == window.id else { continue }

            switch event.kind {
            case .pointer(.entered(let location, let serial)):
                log("pointer entered serial=\(serial) location=\(location.x),\(location.y)")
            case .pointer(.button(let button)):
                log("button \(button.button.rawValue) \(button.state)")
            case .pointer(.moved(let location, let time)):
                log("pointer moved inside input region \(location.x),\(location.y) time=\(time)")
            default:
                break
            }
        }
    }

    nonisolated private static func resetRegions(after seconds: Int64, window: Window) async throws
    {
        try await Task.sleep(for: .seconds(seconds))
        guard try await !window.isClosed else { return }
        try await window.setInputRegion(nil)
        try await window.setOpaqueRegion(nil)
        try await window.redraw { frame in
            draw(frame, restricted: false)
        }
        log("input and opaque regions reset to compositor defaults")
        log("outside-region pointer events should be visible again after reset")
    }

    nonisolated private static func centerRegion(for geometry: SurfaceGeometry) throws
        -> SurfaceRegion
    {
        let width = geometry.logicalSize.width.rawValue
        let height = geometry.logicalSize.height.rawValue
        let regionWidth = max(width / 2, 1)
        let regionHeight = max(height / 2, 1)
        let rect = try LogicalRect(
            x: (width - regionWidth) / 2,
            y: (height - regionHeight) / 2,
            width: regionWidth,
            height: regionHeight
        )
        return SurfaceRegion([rect])
    }

    nonisolated private static func draw(_ frame: borrowing SoftwareFrame, restricted: Bool) {
        let left = Int(frame.width) / 4
        let right = Int(frame.width) - left
        let top = Int(frame.height) / 4
        let bottom = Int(frame.height) - top

        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let inside = x >= left && x < right && row >= top && row < bottom
                let color: UInt32 =
                    if inside {
                        restricted ? 0x0030_A060 : 0x0060_8050
                    } else {
                        restricted ? 0x0020_2020 : 0x0030_3038
                    }
                unsafe pixels[unchecked: x] = color
            }
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[SurfaceRegionSmoke] \(message)")
    }
}
