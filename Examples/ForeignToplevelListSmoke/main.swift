import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum ForeignToplevelListSmoke {
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
            log("feature: ext-foreign-toplevel-list")
            log("capability: \(availability(capabilities.foreignToplevelList))")
            guard capabilities.foreignToplevelList.isAvailable else {
                log("operation: list skip")
                log("cleanup: pass")
                return
            }

            let snapshot = try await display.foreignToplevelListSnapshot()
            log("toplevels: \(snapshot.toplevels.count)")
            for fact in snapshot.toplevels {
                log("toplevel id=\(fact.id?.description ?? "unknown") title=\(fact.title ?? "private") appID=\(fact.appID ?? "private")")
            }
            log("events: typed read-only surface; live stream unavailable in preview")
            log("cleanup: pass")
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
