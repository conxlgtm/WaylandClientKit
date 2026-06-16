import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum OutputManagementSmoke {
    static func main() async throws {
        let flags = Set(CommandLine.arguments.dropFirst().filter { $0.hasPrefix("--") })
        let commonArguments = CommandLine.arguments.dropFirst().filter {
            !["--test-only", "--test-current", "--apply", "--apply-current"].contains($0)
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

            let snapshot = try await display.outputManagementSnapshot()
            log("heads: \(snapshot.heads.count)")
            for head in snapshot.heads {
                log(
                    "head: id=\(head.id) name=\(head.name ?? "<unknown>") enabled=\(head.enabled) modes=\(head.modes.count)"
                )
            }
            log("operation: list pass")

            let proposal = OutputConfigurationProposal(current: snapshot)
            if flags.contains("--test-only") || flags.contains("--test-current") {
                try await display.testOutputConfiguration(proposal)
                log("operation: test-current pass")
            } else {
                log("operation: test-current skip")
            }

            if flags.contains("--apply") || flags.contains("--apply-current") {
                try await display.applyOutputConfiguration(proposal)
                log("operation: apply-current pass")
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
