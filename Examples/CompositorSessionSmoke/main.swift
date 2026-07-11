import WaylandClient
import WaylandExampleSupport

@main
enum CompositorSessionSmoke {
    static func main() async throws {
        _ = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.CompositorSessionSmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 32,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            log("feature: compositor-session-management")
            log(
                "capability: xdg_session_manager_v1 "
                    + availabilityDescription(capabilities.compositorSessionManagement)
            )

            guard capabilities.compositorSessionManagement.isAvailable else {
                log("operation: capability-only(protocol-unavailable)")
                log("local-restoration: SessionStateSmoke")
                log("cleanup: pass")
                return
            }

            log("operation: capability-only(pass)")
            log("events: unavailable-until-durable-session-api")
            log("local-restoration: SessionStateSmoke")
            log("cleanup: pass")
        }
    }

    nonisolated private static func availabilityDescription(
        _ availability: ProtocolAvailability
    ) -> String {
        switch availability {
        case .available(let version):
            "available version=\(version)"
        case .unavailable:
            "unavailable"
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[CompositorSessionSmoke] \(message)")
    }
}
