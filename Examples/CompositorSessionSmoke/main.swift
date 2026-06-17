import WaylandClient
import WaylandExampleSupport

@main
enum CompositorSessionSmoke {
    static func main() async throws {
        _ = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

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
            log("feature: compositor-session-management")
            log(
                "capability: xdg_session_manager_v1 "
                    + availabilityDescription(capabilities.compositorSessionManagement)
            )

            guard capabilities.compositorSessionManagement.isAvailable else {
                log("operation: bind-session skip(protocol-unavailable)")
                log("events: created=0 restored=0 replaced=0")
                log("local-restoration: SessionStateSmoke")
                log("cleanup: pass")
                return
            }

            let snapshot = try await display.compositorSessionEvents()
            log("operation: bind-session pass")
            log("events: \(describe(snapshot.events))")
            log("local-restoration: SessionStateSmoke")
            log("cleanup: pass")
        }
    }

    nonisolated private static func describe(_ events: [CompositorSessionEvent]) -> String {
        var created = 0
        var restored = 0
        var replaced = 0
        for event in events {
            switch event {
            case .created:
                created += 1
            case .restored:
                restored += 1
            case .replaced:
                replaced += 1
            }
        }

        return "created=\(created) restored=\(restored) replaced=\(replaced)"
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
