import Foundation

enum RequestBridgeHandwrittenReason: String, Codable, Equatable, Sendable {
    case conditionalVersion = "conditional_version"
    case customConversion = "custom_conversion"
    case failureInjection = "failure_injection"
    case notExposed = "not_exposed"
    case ownership
    case testRecording = "test_recording"
}

struct RequestBridgeInterfacePolicy: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case wrapperPrefix
        case generatedRequests
        case handwrittenByDefault
        case handwrittenRequests
    }

    let wrapperPrefix: String?
    let generatedRequests: [String]
    let handwrittenByDefault: RequestBridgeHandwrittenReason?
    let handwrittenRequests: [String: RequestBridgeHandwrittenReason]

    init(
        generatedRequests: [String],
        wrapperPrefix: String? = nil,
        handwrittenByDefault: RequestBridgeHandwrittenReason? = nil,
        handwrittenRequests: [String: RequestBridgeHandwrittenReason] = [:]
    ) {
        self.wrapperPrefix = wrapperPrefix
        self.generatedRequests = generatedRequests
        self.handwrittenByDefault = handwrittenByDefault
        self.handwrittenRequests = handwrittenRequests
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wrapperPrefix = try container.decodeIfPresent(String.self, forKey: .wrapperPrefix)
        generatedRequests =
            try container.decodeIfPresent([String].self, forKey: .generatedRequests) ?? []
        handwrittenByDefault = try container.decodeIfPresent(
            RequestBridgeHandwrittenReason.self,
            forKey: .handwrittenByDefault
        )
        handwrittenRequests =
            try container.decodeIfPresent(
                [String: RequestBridgeHandwrittenReason].self,
                forKey: .handwrittenRequests
            ) ?? [:]
    }

    func wrapperName(interfaceName: String, requestName: String) -> String {
        "swl_\(wrapperPrefix ?? interfaceName)_\(requestName)"
    }
}

struct RequestBridgePolicy: Codable, Equatable, Sendable {
    let interfaces: [String: RequestBridgeInterfacePolicy]

    func validate(against protocols: [WaylandProtocolIR]) throws {
        let interfacesByName = try interfaceIndex(protocols: protocols)
        var wrapperNames: Set<String> = []

        for interfaceName in interfaces.keys.sorted() {
            guard let bridge = interfaces[interfaceName] else { continue }
            guard let interface = interfacesByName[interfaceName] else {
                throw policyError("references unknown interface: \(interfaceName)")
            }
            try validate(
                bridge,
                for: interface,
                interfaceName: interfaceName,
                wrapperNames: &wrapperNames
            )
        }
    }

    private func validate(
        _ bridge: RequestBridgeInterfacePolicy,
        for interface: WaylandInterfaceIR,
        interfaceName: String,
        wrapperNames: inout Set<String>
    ) throws {
        if let wrapperPrefix = bridge.wrapperPrefix {
            try validateCIdentifier(
                wrapperPrefix,
                label: "\(interfaceName) wrapperPrefix"
            )
        }

        let requestsByName = interface.requests.reduce(into: [:]) { index, request in
            index[request.name] = request
        }
        let generatedRequests = try validateGeneratedRequestNames(
            bridge.generatedRequests,
            interfaceName: interfaceName
        )
        for requestName in generatedRequests.sorted() {
            guard let request = requestsByName[requestName] else {
                throw policyError(
                    "\(interfaceName) generates unknown request: \(requestName)"
                )
            }
            try validateGeneratedRequest(request, interfaceName: interfaceName)
            try validateWrapperName(
                bridge.wrapperName(
                    interfaceName: interfaceName,
                    requestName: requestName
                ),
                requestName: requestName,
                interfaceName: interfaceName,
                wrapperNames: &wrapperNames
            )
        }

        try validateHandwrittenRequests(
            bridge,
            requestsByName: requestsByName,
            generatedRequests: generatedRequests,
            interfaceName: interfaceName
        )
        try validateRequestCoverage(
            bridge,
            requests: interface.requests,
            generatedRequests: generatedRequests,
            interfaceName: interfaceName
        )
    }

    private func validateGeneratedRequestNames(
        _ requestNames: [String],
        interfaceName: String
    ) throws -> Set<String> {
        let requestNameSet = Set(requestNames)
        guard requestNameSet.count == requestNames.count else {
            throw policyError("\(interfaceName) repeats a generated request")
        }
        return requestNameSet
    }

    private func validateWrapperName(
        _ wrapperName: String,
        requestName: String,
        interfaceName: String,
        wrapperNames: inout Set<String>
    ) throws {
        try validateCIdentifier(
            wrapperName,
            label: "\(interfaceName).\(requestName) wrapper name"
        )
        guard wrapperNames.insert(wrapperName).inserted else {
            throw policyError("produces wrapper more than once: \(wrapperName)")
        }
    }

    private func validateHandwrittenRequests(
        _ bridge: RequestBridgeInterfacePolicy,
        requestsByName: [String: WaylandMessageIR],
        generatedRequests: Set<String>,
        interfaceName: String
    ) throws {
        for requestName in bridge.handwrittenRequests.keys.sorted() {
            guard requestsByName[requestName] != nil else {
                throw policyError(
                    "\(interfaceName) classifies unknown request: \(requestName)"
                )
            }
            guard !generatedRequests.contains(requestName) else {
                throw policyError(
                    "\(interfaceName).\(requestName) is both generated and handwritten"
                )
            }
        }
    }

    private func validateRequestCoverage(
        _ bridge: RequestBridgeInterfacePolicy,
        requests: [WaylandMessageIR],
        generatedRequests: Set<String>,
        interfaceName: String
    ) throws {
        guard bridge.handwrittenByDefault == nil else { return }
        for request in requests
        where !generatedRequests.contains(request.name)
            && bridge.handwrittenRequests[request.name] == nil
        {
            throw policyError(
                "\(interfaceName).\(request.name) is not generated or handwritten"
            )
        }
    }

    private func interfaceIndex(
        protocols: [WaylandProtocolIR]
    ) throws -> [String: WaylandInterfaceIR] {
        var interfacesByName: [String: WaylandInterfaceIR] = [:]
        for interface in protocols.flatMap(\.interfaces) {
            guard interfacesByName.updateValue(interface, forKey: interface.name) == nil else {
                throw policyError("XML declares interface more than once: \(interface.name)")
            }
        }
        return interfacesByName
    }

    private func validateGeneratedRequest(
        _ request: WaylandMessageIR,
        interfaceName: String
    ) throws {
        let newIDs = request.arguments.filter { $0.wireType == .newID }
        guard newIDs.count <= 1 else {
            throw policyError(
                "\(interfaceName).\(request.name) creates more than one object"
            )
        }
        if let newID = newIDs.first, newID.interfaceName == nil {
            throw policyError(
                "\(interfaceName).\(request.name) has an untyped new_id"
            )
        }
    }

    private func validateCIdentifier(_ value: String, label: String) throws {
        guard let first = value.first, first == "_" || first.isLetter,
            value.allSatisfy({ $0 == "_" || $0.isLetter || $0.isNumber })
        else {
            throw policyError("has invalid \(label): \(value)")
        }
    }

    private func policyError(_ message: String) -> ToolError {
        ToolError(
            "request bridge policy \(message)",
            exitCode: ToolExitCode.data
        )
    }
}
