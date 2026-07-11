import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum OutputTopologySmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.OutputTopologySmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            let topology = try await display.outputTopology()

            log("feature: output-topology")
            log("capability: wl_output required")
            log("capability: xdg_output \(availability(capabilities.xdgOutput))")
            log("outputs: \(topology.count)")
            for output in topology {
                log(outputDescription(output))
            }

            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Output Topology Smoke",
                    appID: "wayland-client-kit-output-topology-smoke",
                    initialWidth: 240,
                    initialHeight: 160,
                    closeRequestPolicy: .requestOnly
                )
            )
            try await window.show { frame in
                draw(frame)
            }
            let snapshot = try await window.stateSnapshot
            log("window outputs: \(snapshot.outputs.map(\.description).joined(separator: ","))")

            if let autoCloseSeconds = options.autoCloseSeconds {
                try await Task.sleep(for: .seconds(autoCloseSeconds))
            }
            await window.close()
            log("cleanup: pass")
        }
    }

    nonisolated private static func draw(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for index in 0..<pixels.count {
                let shade = UInt32((index + row) & 0x7F)
                unsafe pixels[unchecked: index] = 0x0020_3040 | (shade << 8)
            }
        }
    }

    nonisolated private static func outputDescription(_ output: OutputSnapshot) -> String {
        let logical =
            output.logicalGeometry.map {
                "\($0.x),\($0.y) \($0.width.rawValue)x\($0.height.rawValue)"
            } ?? "unavailable"
        let physical =
            output.geometry.map {
                "\($0.physicalWidthMillimeters)x\($0.physicalHeightMillimeters)mm"
            } ?? "unavailable"
        let transform = output.geometry.map { "\($0.transform)" } ?? "unavailable"
        let mode =
            output.currentMode.map {
                "\($0.width.rawValue)x\($0.height.rawValue)@\(refreshDescription($0.refresh))"
            } ?? "unavailable"

        return "output id=\(output.id) name=\(output.name ?? "unknown") "
            + "description=\(output.description ?? "unknown") scale=\(output.scale.rawValue) "
            + "transform=\(transform) logical=\(logical) physical=\(physical) mode=\(mode)"
    }

    nonisolated private static func refreshDescription(_ refresh: OutputRefreshRate) -> String {
        switch refresh {
        case .unspecified:
            "unspecified"
        case .milliHertz(let value):
            "\(value.rawValue)mHz"
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
        print(message)
    }
}
