import Foundation
import WaylandClient

@main
enum XDGActivationSmoke {
    static func main() async throws {
        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.XDGActivationSmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 16,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            log("xdg-activation capability \(availabilityDescription(capabilities.xdgActivation))")
            guard capabilities.xdgActivation.isAvailable else {
                log("xdg-activation unavailable; skipping token request")
                return
            }

            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit XDG Activation Smoke",
                    appID: "wayland-client-kit-xdg-activation-smoke",
                    initialWidth: 240,
                    initialHeight: 160
                )
            )
            try await window.show(drawFrame)

            do {
                log("requesting activation token")
                let token = try await window.requestActivationToken(
                    appID: "wayland-client-kit-xdg-activation-smoke"
                )
                log("activation token received length=\(token.value.count)")
                try await window.activate(using: token)
                log("activate request sent window=\(window.id)")
            } catch {
                log("activation request failed \(error)")
            }

            await window.close()
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
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    nonisolated private static func drawFrame(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let red = UInt32((x * 255) / max(Int(frame.width), 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                let blue = UInt32(0xA0)
                unsafe pixels[unchecked: x] = (red << 16) | (green << 8) | blue
            }
        }
    }
}
