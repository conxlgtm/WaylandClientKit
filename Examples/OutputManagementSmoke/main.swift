import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum OutputManagementSmoke {
    static func main() async throws {
        let flags = Set(CommandLine.arguments.dropFirst().filter { $0.hasPrefix("--") })
        let commonArguments = CommandLine.arguments.dropFirst().filter {
            $0 != "--test-only" && $0 != "--apply"
        }
        _ = try ExampleRunOptions.parse(commonArguments[...])

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
            log("feature: output-management")
            log("capability: \(availability(capabilities.outputManagement))")
            guard capabilities.outputManagement.isAvailable else {
                log("operation: list skip")
                log("cleanup: pass")
                return
            }

            log("heads: deferred")
            log("operation: list deferred")
            if flags.contains("--test-only") || flags.contains("--apply") {
                log("operation: test-current deferred")
            } else {
                log("operation: test-current skip")
            }

            if flags.contains("--apply") {
                log("operation: apply-current deferred")
            } else {
                log("operation: apply-current skipped-by-default")
            }
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
        print("[OutputManagementSmoke] \(message)")
    }
}
