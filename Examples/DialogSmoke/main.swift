import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum DialogSmoke {
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
            let capabilities = try await display.capabilities()
            log("feature: xdg-dialog")
            log("capability: \(availability(capabilities.xdgDialog))")
            guard capabilities.xdgDialog.isAvailable else {
                log("operation: create-dialog skip")
                log("cleanup: pass")
                return
            }

            let parent = try await makeWindow(
                display,
                title: "WaylandClientKit Dialog Parent",
                appID: "wayland-client-kit-dialog-smoke-parent",
                width: 360,
                height: 220
            )
            let child = try await makeWindow(
                display,
                title: "WaylandClientKit Dialog Child",
                appID: "wayland-client-kit-dialog-smoke-child",
                width: 260,
                height: 160
            )

            try await parent.show(drawParent)
            try await child.show(drawChild)

            let dialog = try await child.createDialog(parent: parent, modal: true)
            log("operation: create-dialog pass id=\(dialog.id)")
            log("operation: set-modal pass")
            try await dialog.unsetModal()
            log("operation: unset-modal pass")

            if let seconds = options.autoCloseSeconds {
                try await Task.sleep(for: .seconds(seconds))
            }

            await child.close()
            log("operation: close-child pass")
            await parent.close()
            log("operation: close-parent pass")
            log("cleanup: pass")
        }
    }

    private static func makeWindow(
        _ display: WaylandDisplay,
        title: String,
        appID: String,
        width: UInt32,
        height: UInt32
    ) async throws -> Window {
        try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: title,
                appID: appID,
                initialWidth: width,
                initialHeight: height,
                closeRequestPolicy: .requestOnly
            )
        )
    }

    nonisolated private static func drawParent(_ frame: borrowing SoftwareFrame) {
        draw(frame, base: 0x0018_2C3A)
    }

    nonisolated private static func drawChild(_ frame: borrowing SoftwareFrame) {
        draw(frame, base: 0x003A_2418)
    }

    nonisolated private static func draw(_ frame: borrowing SoftwareFrame, base: UInt32) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let shade = UInt32((x + row) & 0x3F)
                unsafe pixels[unchecked: x] = base | (shade << 8)
            }
        }
    }

    nonisolated private static func availability(_ availability: ProtocolAvailability) -> String {
        switch availability {
        case .available(let version):
            "available version=\(version)"
        case .unavailable:
            "unavailable"
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[DialogSmoke] \(message)")
    }
}
