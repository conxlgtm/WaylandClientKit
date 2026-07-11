import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum SystemBellSmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.SystemBellSmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 32,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            log("feature: system-bell")
            log("capability: \(availabilityDescription(capabilities.systemBell))")
            guard capabilities.systemBell.isAvailable else {
                log("operation: ring-display-bell skip")
                log("operation: ring-window-bell skip")
                log("cleanup: pass")
                return
            }

            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit System Bell Smoke",
                    appID: "wayland-client-kit-system-bell-smoke",
                    initialWidth: 280,
                    initialHeight: 180,
                    closeRequestPolicy: .requestOnly
                )
            )
            try await window.show(drawFrame)

            try await display.ringSystemBell()
            log("operation: ring-display-bell pass")
            try await window.ringSystemBell()
            log("operation: ring-window-bell pass")

            if let autoCloseSeconds = options.autoCloseSeconds {
                try await Task.sleep(for: .seconds(autoCloseSeconds))
            }
            await window.close()
            log("cleanup: pass")
        }
    }

    nonisolated private static func drawFrame(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let red = UInt32((x * 255) / max(Int(frame.width), 1))
                let blue = UInt32((row * 255) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: x] = (red << 16) | 0x0000_5000 | blue
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
        print("[SystemBellSmoke] \(message)")
    }
}
