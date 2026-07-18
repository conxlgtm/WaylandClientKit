import Foundation

enum ListenerBridgeForwarding: String, Codable, Equatable, Sendable {
    case generated
    case handwritten
}

struct ListenerBridgeInterfacePolicy: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case callbackPrefix
        case installerPrefix
        case forwarding
        case omittedEvents
        case eventCallbackNames
    }

    let callbackPrefix: String
    let installerPrefix: String?
    let forwarding: ListenerBridgeForwarding
    let omittedEvents: [String]
    let eventCallbackNames: [String: String]

    init(
        callbackPrefix: String,
        forwarding: ListenerBridgeForwarding,
        installerPrefix: String? = nil,
        omittedEvents: [String] = [],
        eventCallbackNames: [String: String] = [:]
    ) {
        self.callbackPrefix = callbackPrefix
        self.installerPrefix = installerPrefix
        self.forwarding = forwarding
        self.omittedEvents = omittedEvents
        self.eventCallbackNames = eventCallbackNames
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        callbackPrefix = try container.decode(String.self, forKey: .callbackPrefix)
        installerPrefix = try container.decodeIfPresent(String.self, forKey: .installerPrefix)
        forwarding = try container.decode(ListenerBridgeForwarding.self, forKey: .forwarding)
        omittedEvents =
            try container.decodeIfPresent([String].self, forKey: .omittedEvents) ?? []
        eventCallbackNames =
            try container.decodeIfPresent(
                [String: String].self,
                forKey: .eventCallbackNames
            ) ?? [:]
    }

    var effectiveInstallerPrefix: String {
        installerPrefix ?? callbackPrefix
    }

    func callbackName(for eventName: String) -> String {
        eventCallbackNames[eventName] ?? eventName
    }
}

struct ListenerBridgePolicy: Codable, Equatable, Sendable {
    let interfaces: [String: ListenerBridgeInterfacePolicy]

    func validate(against protocols: [WaylandProtocolIR]) throws {
        let interfacesByName = try interfaceIndex(protocols: protocols)
        var callbackPrefixes: Set<String> = []
        var installerSymbols: Set<String> = []

        for interfaceName in interfaces.keys.sorted() {
            guard let bridge = interfaces[interfaceName] else { continue }
            guard let interface = interfacesByName[interfaceName] else {
                throw policyError("references unknown interface: \(interfaceName)")
            }
            guard !interface.events.isEmpty else {
                throw policyError("selects interface without events: \(interfaceName)")
            }
            try validateCIdentifier(
                bridge.callbackPrefix,
                label: "\(interfaceName) callbackPrefix"
            )
            try validateCIdentifier(
                bridge.effectiveInstallerPrefix,
                label: "\(interfaceName) installerPrefix"
            )
            guard callbackPrefixes.insert(bridge.callbackPrefix).inserted else {
                throw policyError(
                    "uses callbackPrefix more than once: \(bridge.callbackPrefix)"
                )
            }
            let installerSymbol = "swl_\(bridge.effectiveInstallerPrefix)_add_listener"
            guard installerSymbols.insert(installerSymbol).inserted else {
                throw policyError("produces installer more than once: \(installerSymbol)")
            }
            try validateOmittedEvents(bridge, interface: interface)
            try validateEventCallbackNames(bridge, interface: interface)
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

    private func validateOmittedEvents(
        _ bridge: ListenerBridgeInterfacePolicy,
        interface: WaylandInterfaceIR
    ) throws {
        let availableEvents = Set(interface.events.map(\.name))
        let omittedEvents = Set(bridge.omittedEvents)
        guard omittedEvents.count == bridge.omittedEvents.count else {
            throw policyError("\(interface.name) repeats an omitted event")
        }
        for event in omittedEvents.sorted() where !availableEvents.contains(event) {
            throw policyError("\(interface.name) omits unknown event: \(event)")
        }
        guard omittedEvents.count < interface.events.count else {
            throw policyError("\(interface.name) omits every event")
        }
    }

    private func validateEventCallbackNames(
        _ bridge: ListenerBridgeInterfacePolicy,
        interface: WaylandInterfaceIR
    ) throws {
        let availableEvents = Set(interface.events.map(\.name))
        var callbackNames: Set<String> = []
        for event in interface.events where !bridge.omittedEvents.contains(event.name) {
            let callbackName = bridge.callbackName(for: event.name)
            try validateCIdentifier(
                callbackName,
                label: "\(interface.name).\(event.name) callback name"
            )
            guard callbackNames.insert(callbackName).inserted else {
                throw policyError(
                    "\(interface.name) produces callback name more than once: \(callbackName)"
                )
            }
        }
        for eventName in bridge.eventCallbackNames.keys.sorted()
        where !availableEvents.contains(eventName) {
            throw policyError(
                "\(interface.name) renames unknown event callback: \(eventName)"
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
            "listener bridge policy \(message)",
            exitCode: ToolExitCode.data
        )
    }
}
