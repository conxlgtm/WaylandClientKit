import Foundation

struct ListenerBridgeArtifacts: Equatable, Sendable {
    let header: String
    let source: String
}

struct ResolvedListenerBridge: Sendable {
    let interface: WaylandInterfaceIR
    let policy: ListenerBridgeInterfacePolicy
    let generatedHeaderInclude: String?

    var events: [WaylandMessageIR] {
        let omittedEvents = Set(policy.omittedEvents)
        return interface.events.filter { !omittedEvents.contains($0.name) }
    }
}

enum ListenerBridgeGeneration {
    static let policyPath = "protocols/listener-bridge-policy.json"
    static let headerOutputPath =
        "Sources/CWaylandProtocols/include/generated/shims/listener-bridges.h"
    static let sourceOutputPath =
        "Sources/CWaylandProtocols/generated/shims/listener-bridges.c"

    static func render(
        protocols: [WaylandProtocolIR],
        manifest: ProtocolManifest,
        policy: ListenerBridgePolicy
    ) throws -> ListenerBridgeArtifacts {
        try policy.validate(against: protocols)
        let bridges = try resolveBridges(
            protocols: protocols,
            manifest: manifest,
            policy: policy
        )
        return ListenerBridgeArtifacts(
            header: ListenerBridgeHeaderRenderer.render(bridges: bridges),
            source: ListenerBridgeSourceRenderer.render(bridges: bridges)
        )
    }

    private static func resolveBridges(
        protocols: [WaylandProtocolIR],
        manifest: ProtocolManifest,
        policy: ListenerBridgePolicy
    ) throws -> [ResolvedListenerBridge] {
        guard protocols.count == manifest.protocols.count else {
            throw ToolError(
                "listener bridge generation requires one parsed protocol per manifest entry",
                exitCode: ToolExitCode.data
            )
        }

        var sourcesByInterface: [String: ResolvedProtocolInterface] = [:]
        for (entry, protocolIR) in zip(manifest.protocols, protocols) {
            let headerInclude = try generatedHeaderInclude(for: entry)
            for interface in protocolIR.interfaces {
                let resolved = ResolvedProtocolInterface(
                    interface: interface,
                    generatedHeaderInclude: headerInclude
                )
                guard sourcesByInterface.updateValue(resolved, forKey: interface.name) == nil else {
                    throw ToolError(
                        "Wayland XML declares interface more than once: \(interface.name)",
                        exitCode: ToolExitCode.data
                    )
                }
            }
        }

        return try policy.interfaces.keys.sorted().map { interfaceName in
            guard let source = sourcesByInterface[interfaceName],
                let interfacePolicy = policy.interfaces[interfaceName]
            else {
                throw ToolError(
                    "listener bridge policy could not resolve interface: \(interfaceName)",
                    exitCode: ToolExitCode.data
                )
            }
            return ResolvedListenerBridge(
                interface: source.interface,
                policy: interfacePolicy,
                generatedHeaderInclude: source.generatedHeaderInclude
            )
        }
    }

    private static func generatedHeaderInclude(for entry: ProtocolEntry) throws -> String? {
        if entry.name == "wayland-core" {
            return nil
        }
        let includeRoot = "Sources/CWaylandProtocols/include/"
        guard entry.effectiveGeneratedHeaderPath.hasPrefix(includeRoot) else {
            throw ToolError(
                "listener bridge protocol header is outside the C include root: "
                    + entry.effectiveGeneratedHeaderPath,
                exitCode: ToolExitCode.data
            )
        }
        return String(entry.effectiveGeneratedHeaderPath.dropFirst(includeRoot.count))
    }
}

private struct ResolvedProtocolInterface {
    let interface: WaylandInterfaceIR
    let generatedHeaderInclude: String?
}

enum ListenerBridgeC {
    static func pointerType(interfaceName: String) -> String {
        "struct \(interfaceName) *"
    }

    static func argumentType(_ argument: WaylandArgumentIR) -> String {
        switch argument.wireType {
        case .int:
            "int32_t"
        case .uint:
            "uint32_t"
        case .fixed:
            "wl_fixed_t"
        case .string:
            "const char *"
        case .object, .newID:
            argument.interfaceName.map(pointerType(interfaceName:)) ?? "void *"
        case .array:
            "struct wl_array *"
        case .fileDescriptor:
            "int32_t"
        }
    }

    static func argumentName(_ argument: WaylandArgumentIR) -> String {
        "event_\(argument.name)"
    }

    static func declaration(type: String, name: String) -> String {
        if type.hasSuffix("*") {
            return type + name
        }
        return "\(type) \(name)"
    }
}

extension ProtocolTooling {
    func loadListenerBridgePolicy() throws -> ListenerBridgePolicy {
        try JSONHelpers.decode(
            ListenerBridgePolicy.self,
            from: repository.url(ListenerBridgeGeneration.policyPath)
        )
    }

    func renderListenerBridgeArtifacts() throws -> ListenerBridgeArtifacts {
        try ListenerBridgeGeneration.render(
            protocols: loadProtocolIRs(),
            manifest: loadManifest(),
            policy: loadListenerBridgePolicy()
        )
    }

    func renderListenerBridgeArtifacts(
        protocols: [WaylandProtocolIR],
        manifest: ProtocolManifest
    ) throws -> ListenerBridgeArtifacts {
        try ListenerBridgeGeneration.render(
            protocols: protocols,
            manifest: manifest,
            policy: loadListenerBridgePolicy()
        )
    }

    func writeListenerBridgeArtifacts(
        _ artifacts: ListenerBridgeArtifacts,
        outputRoot: URL
    ) throws {
        let header = outputRoot.appendingPathComponent(
            ListenerBridgeGeneration.headerOutputPath
        )
        let source = outputRoot.appendingPathComponent(
            ListenerBridgeGeneration.sourceOutputPath
        )
        try fileSystem.writeText(artifacts.header, to: header)
        try fileSystem.writeText(artifacts.source, to: source)
    }
}
