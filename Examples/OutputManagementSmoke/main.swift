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

            let snapshot = try await display.outputManagementSnapshot()
            log("heads: \(snapshot.heads.count)")
            for head in snapshot.heads {
                log(headDescription(head))
            }
            log("operation: list pass")

            let proposal = OutputConfigurationProposal(current: snapshot)
            if flags.contains("--test-only") || flags.contains("--apply") {
                do {
                    try await display.testOutputConfiguration(proposal)
                    log("operation: test-current pass")
                } catch {
                    log("operation: test-current skip error=\(error)")
                }
            } else {
                log("operation: test-current skip")
            }

            if flags.contains("--apply") {
                do {
                    try await display.applyOutputConfiguration(proposal)
                    log("operation: apply-current pass")
                } catch {
                    log("operation: apply-current skip error=\(error)")
                }
            } else {
                log("operation: apply-current skipped-by-default")
            }
            log("cleanup: pass")
        }
    }

    nonisolated private static func headDescription(_ head: OutputHead) -> String {
        let position = head.position.map { "\($0.x),\($0.y)" } ?? "unknown"
        let scale = head.scale.map(\.description) ?? "unknown"
        let transform = head.transform.map { "\($0)" } ?? "unknown"
        let modes = head.modes.map(modeDescription).joined(separator: ",")
        return "head id=\(head.id) name=\(head.name ?? "unknown") "
            + "description=\(head.description ?? "unknown") enabled=\(head.enabled) "
            + "position=\(position) scale=\(scale) transform=\(transform) modes=[\(modes)]"
    }

    nonisolated private static func modeDescription(_ mode: OutputMode) -> String {
        let refresh: String
        switch mode.refresh {
        case .unspecified:
            refresh = "unspecified"
        case .milliHertz(let value):
            refresh = "\(value.rawValue)mHz"
        }

        return "\(mode.width.rawValue)x\(mode.height.rawValue)@\(refresh)"
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
