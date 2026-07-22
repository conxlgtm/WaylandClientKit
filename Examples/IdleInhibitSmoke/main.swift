import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum IdleInhibitSmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.IdleInhibitSmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                eventCapacity: 32,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            log("feature: idle-inhibit")
            log("capability: \(availabilityDescription(capabilities.idleInhibit))")
            guard capabilities.idleInhibit.isAvailable else {
                log("operation: create-inhibitor skip")
                log("operation: destroy-inhibitor skip")
                log("cleanup: pass")
                return
            }

            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Idle Inhibit Smoke",
                    appID: "wayland-client-kit-idle-inhibit-smoke",
                    initialWidth: 280,
                    initialHeight: 180,
                    closeRequestPolicy: .requestOnly
                )
            )
            try await window.show(drawFrame)

            let inhibitor = try await window.inhibitIdle()
            log("operation: create-inhibitor pass id=\(inhibitor.id)")
            try await Task.sleep(for: .seconds(options.autoCloseSeconds ?? 3))
            try await inhibitor.destroy()
            log("operation: destroy-inhibitor pass")
            await window.close()
            log("cleanup: pass")
        }
    }

    nonisolated private static func drawFrame(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let blue = UInt32((x * 255) / max(Int(frame.width), 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: x] = 0x0030_0000 | (green << 8) | blue
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
        print("[IdleInhibitSmoke] \(message)")
    }
}
