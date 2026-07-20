import Foundation

struct RegistryBindBridgeArtifacts: Equatable, Sendable {
    let header: String
    let source: String
}

struct ResolvedRegistryBindBridge: Equatable, Sendable {
    let interface: WaylandInterfaceIR
    let policy: WaylandInterfaceGenerationPolicy
    let generatedHeaderInclude: String?

    var functionName: String {
        "swl_registry_bind_\(interface.name)"
    }
}

enum RegistryBindBridgeGeneration {
    static let headerOutputPath =
        "Sources/CWaylandProtocols/include/generated/shims/registry-bind-bridges.h"
    static let sourceOutputPath =
        "Sources/CWaylandProtocols/generated/shims/registry-bind-bridges.c"

    static func render(
        protocols: [WaylandProtocolIR],
        manifest: ProtocolManifest,
        policy: WaylandProtocolGenerationPolicy
    ) throws -> RegistryBindBridgeArtifacts {
        let bridges = try resolve(
            protocols: protocols,
            manifest: manifest,
            policy: policy
        )
        return RegistryBindBridgeArtifacts(
            header: RegistryBindBridgeHeaderRenderer.render(bridges: bridges),
            source: RegistryBindBridgeSourceRenderer.render(bridges: bridges)
        )
    }

    static func resolve(
        protocols: [WaylandProtocolIR],
        manifest: ProtocolManifest,
        policy: WaylandProtocolGenerationPolicy
    ) throws -> [ResolvedRegistryBindBridge] {
        try policy.validate(against: protocols)
        guard protocols.count == manifest.protocols.count else {
            throw generationError(
                "could not pair every parsed protocol with its manifest entry"
            )
        }

        var interfacesByName: [String: ResolvedProtocolInterface] = [:]
        for (protocolIR, entry) in zip(protocols, manifest.protocols) {
            let generatedHeaderInclude = try generatedHeaderInclude(for: entry)
            for interface in protocolIR.interfaces {
                guard
                    interfacesByName.updateValue(
                        ResolvedProtocolInterface(
                            interface: interface,
                            generatedHeaderInclude: generatedHeaderInclude
                        ),
                        forKey: interface.name
                    ) == nil
                else {
                    throw generationError(
                        "XML declares interface more than once: \(interface.name)"
                    )
                }
            }
        }

        return try policy.interfaces.keys.sorted().compactMap { interfaceName in
            guard let interfacePolicy = policy.interfaces[interfaceName],
                interfacePolicy.globalBinding != nil
            else {
                return nil
            }
            guard let source = interfacesByName[interfaceName] else {
                throw generationError(
                    "could not resolve registry global: \(interfaceName)"
                )
            }
            return ResolvedRegistryBindBridge(
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
            throw generationError(
                "protocol header is outside the C include root: "
                    + entry.effectiveGeneratedHeaderPath
            )
        }
        return String(entry.effectiveGeneratedHeaderPath.dropFirst(includeRoot.count))
    }

    private static func generationError(_ message: String) -> ToolError {
        ToolError(
            "registry bind bridge generation \(message)",
            exitCode: ToolExitCode.data
        )
    }
}

private struct ResolvedProtocolInterface {
    let interface: WaylandInterfaceIR
    let generatedHeaderInclude: String?
}

extension ProtocolTooling {
    func renderRegistryBindBridgeArtifacts() throws -> RegistryBindBridgeArtifacts {
        try RegistryBindBridgeGeneration.render(
            protocols: loadProtocolIRs(),
            manifest: loadManifest(),
            policy: loadGenerationPolicy()
        )
    }

    func renderRegistryBindBridgeArtifacts(
        protocols: [WaylandProtocolIR],
        manifest: ProtocolManifest
    ) throws -> RegistryBindBridgeArtifacts {
        try RegistryBindBridgeGeneration.render(
            protocols: protocols,
            manifest: manifest,
            policy: loadGenerationPolicy()
        )
    }

    func writeRegistryBindBridgeArtifacts(
        _ artifacts: RegistryBindBridgeArtifacts,
        outputRoot: URL
    ) throws {
        let header = outputRoot.appendingPathComponent(
            RegistryBindBridgeGeneration.headerOutputPath
        )
        let source = outputRoot.appendingPathComponent(
            RegistryBindBridgeGeneration.sourceOutputPath
        )
        try fileSystem.writeText(artifacts.header, to: header)
        try fileSystem.writeText(artifacts.source, to: source)
    }
}
