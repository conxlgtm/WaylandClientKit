import Foundation

struct RequestBridgeArtifacts: Equatable, Sendable {
    let header: String
    let source: String
}

struct ResolvedRequestBridge: Equatable, Sendable {
    let interface: WaylandInterfaceIR
    let request: WaylandMessageIR
    let interfacePolicy: RequestBridgeInterfacePolicy
    let generatedHeaderInclude: String?

    var functionName: String {
        interfacePolicy.wrapperName(
            interfaceName: interface.name,
            requestName: request.name
        )
    }
}

enum RequestBridgeGeneration {
    static let policyPath = "protocols/request-bridge-policy.json"
    static let headerOutputPath =
        "Sources/CWaylandProtocols/include/generated/shims/request-bridges.h"
    static let sourceOutputPath =
        "Sources/CWaylandProtocols/generated/shims/request-bridges.c"

    static func render(
        protocols: [WaylandProtocolIR],
        manifest: ProtocolManifest,
        policy: RequestBridgePolicy
    ) throws -> RequestBridgeArtifacts {
        let bridges = try resolve(
            protocols: protocols,
            manifest: manifest,
            policy: policy
        )
        return RequestBridgeArtifacts(
            header: RequestBridgeHeaderRenderer.render(bridges: bridges),
            source: RequestBridgeSourceRenderer.render(bridges: bridges)
        )
    }

    static func resolve(
        protocols: [WaylandProtocolIR],
        manifest: ProtocolManifest,
        policy: RequestBridgePolicy
    ) throws -> [ResolvedRequestBridge] {
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

        var bridges: [ResolvedRequestBridge] = []
        for interfaceName in policy.interfaces.keys.sorted() {
            guard let interfacePolicy = policy.interfaces[interfaceName],
                let source = interfacesByName[interfaceName]
            else {
                throw generationError("could not resolve interface: \(interfaceName)")
            }
            let selectedRequests = Set(interfacePolicy.generatedRequests)
            for request in source.interface.requests where selectedRequests.contains(request.name) {
                bridges.append(
                    ResolvedRequestBridge(
                        interface: source.interface,
                        request: request,
                        interfacePolicy: interfacePolicy,
                        generatedHeaderInclude: source.generatedHeaderInclude
                    )
                )
            }
        }
        return bridges
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
            "request bridge generation \(message)",
            exitCode: ToolExitCode.data
        )
    }
}

private struct ResolvedProtocolInterface {
    let interface: WaylandInterfaceIR
    let generatedHeaderInclude: String?
}

enum RequestBridgeC {
    static func returnType(for request: WaylandMessageIR) -> String {
        guard
            let createdInterface = request.arguments.first(where: { argument in
                argument.wireType == .newID
            })?.interfaceName
        else {
            return "void"
        }
        return ListenerBridgeC.pointerType(interfaceName: createdInterface)
    }

    static func requestArguments(_ request: WaylandMessageIR) -> [WaylandArgumentIR] {
        request.arguments.filter { $0.wireType != .newID }
    }

    static func argumentName(_ argument: WaylandArgumentIR) -> String {
        "request_\(argument.name)"
    }

    static func parameterDeclarations(for bridge: ResolvedRequestBridge) -> [String] {
        [
            ListenerBridgeC.declaration(
                type: ListenerBridgeC.pointerType(interfaceName: bridge.interface.name),
                name: "object"
            )
        ]
            + requestArguments(bridge.request).map { argument in
                ListenerBridgeC.declaration(
                    type: ListenerBridgeC.argumentType(argument),
                    name: argumentName(argument)
                )
            }
    }

    static func callArguments(for bridge: ResolvedRequestBridge) -> [String] {
        ["object"] + requestArguments(bridge.request).map(argumentName)
    }
}

extension ProtocolTooling {
    func loadRequestBridgePolicy() throws -> RequestBridgePolicy {
        try JSONHelpers.decode(
            RequestBridgePolicy.self,
            from: repository.url(RequestBridgeGeneration.policyPath)
        )
    }

    func renderRequestBridgeArtifacts() throws -> RequestBridgeArtifacts {
        try RequestBridgeGeneration.render(
            protocols: loadProtocolIRs(),
            manifest: loadManifest(),
            policy: loadRequestBridgePolicy()
        )
    }

    func renderRequestBridgeArtifacts(
        protocols: [WaylandProtocolIR],
        manifest: ProtocolManifest
    ) throws -> RequestBridgeArtifacts {
        try RequestBridgeGeneration.render(
            protocols: protocols,
            manifest: manifest,
            policy: loadRequestBridgePolicy()
        )
    }

    func writeRequestBridgeArtifacts(
        _ artifacts: RequestBridgeArtifacts,
        outputRoot: URL
    ) throws {
        let header = outputRoot.appendingPathComponent(RequestBridgeGeneration.headerOutputPath)
        let source = outputRoot.appendingPathComponent(RequestBridgeGeneration.sourceOutputPath)
        try fileSystem.writeText(artifacts.header, to: header)
        try fileSystem.writeText(artifacts.source, to: source)
    }
}
