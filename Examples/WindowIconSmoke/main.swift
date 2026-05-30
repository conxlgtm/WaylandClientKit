import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum WindowIconSmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 32,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            log("feature: window-icon")
            log("capability: \(availabilityDescription(capabilities.xdgToplevelIcon))")
            guard capabilities.xdgToplevelIcon.isAvailable else {
                log("operation: set-named-icon skip")
                log("operation: set-pixel-icon skip")
                log("operation: reset-icon skip")
                log("cleanup: pass")
                return
            }

            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "SwiftWayland Window Icon Smoke",
                    appID: "swift-wayland-window-icon-smoke",
                    initialWidth: 280,
                    initialHeight: 180,
                    closeRequestPolicy: .requestOnly
                )
            )
            try await window.show(drawFrame)

            do {
                try await window.setIcon(.named(try WindowIconName("applications-graphics")))
                log("operation: set-named-icon pass")

                try await window.setIcon(.xrgb8888(try makePixelIcon()))
                log("operation: set-pixel-icon pass")

                try await window.setIcon(.none)
                log("operation: reset-icon pass")
            } catch {
                log("operation: window-icon fail error=\(error)")
            }

            if let autoCloseSeconds = options.autoCloseSeconds {
                try await Task.sleep(for: .seconds(autoCloseSeconds))
                await window.close()
            } else {
                await window.close()
            }
            log("cleanup: pass")
        }
    }

    nonisolated private static func makePixelIcon() throws -> WindowIconImage {
        let size = try PositivePixelSize(width: 32, height: 32)
        var pixels = Array(repeating: UInt32(0x0020_3040), count: 32 * 32)
        for y in 0..<32 {
            for x in 0..<32 {
                let index = (y * 32) + x
                if x == y || x + y == 31 {
                    pixels[index] = 0x00FF_D050
                } else if x > 8 && x < 24 && y > 8 && y < 24 {
                    pixels[index] = 0x0030_A0FF
                }
            }
        }

        return try WindowIconImage(size: size, pixels: pixels)
    }

    nonisolated private static func drawFrame(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let red = UInt32((x * 255) / max(Int(frame.width), 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: x] = (red << 16) | (green << 8) | 0x40
            }
        }
    }

    nonisolated private static func availabilityDescription(
        _ availability: ProtocolAvailability
    ) -> String {
        switch availability {
        case .unavailable:
            "unavailable"
        case .available(let version):
            "available version=\(version)"
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[WindowIconSmoke] \(message)")
    }
}
