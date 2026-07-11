import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum ForeignToplevelListSmoke {
    static func main() async throws {
        _ = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.ForeignToplevelListSmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 32,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            log("feature: ext-foreign-toplevel-list")
            log("capability: \(availability(capabilities.foreignToplevelList))")
            guard capabilities.foreignToplevelList.isAvailable else {
                log("operation: list skip")
                log("cleanup: pass")
                return
            }

            let snapshot = try await display.foreignToplevelListSnapshot()
            log("toplevels: \(snapshot.toplevels.count)")
            log("events: \(snapshot.events.count)")
            for event in snapshot.events {
                log("event: \(describe(event))")
            }
            log("operation: list pass")
            log("cleanup: pass")
        }
    }

    nonisolated private static func describe(_ event: ForeignToplevelEvent) -> String {
        switch event {
        case .added(let snapshot):
            "added id=\(snapshot.id) title=\(snapshot.title ?? "<private>") appID=\(snapshot.appID ?? "<private>")"
        case .updated(let snapshot):
            "updated id=\(snapshot.id) title=\(snapshot.title ?? "<private>") appID=\(snapshot.appID ?? "<private>")"
        case .removed(let id):
            "removed id=\(id)"
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
        print("[ForeignToplevelListSmoke] \(message)")
    }
}
