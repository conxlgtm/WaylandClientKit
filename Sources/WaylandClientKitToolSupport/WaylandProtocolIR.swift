import Foundation

/// The schema facts parsed from one Wayland protocol XML file.
public struct WaylandProtocolIR: Codable, Equatable, Sendable {
    /// The protocol name from the XML root element.
    public let name: String

    /// The interfaces in source order.
    public let interfaces: [WaylandInterfaceIR]

    /// Creates a protocol schema value.
    public init(name protocolName: String, interfaces protocolInterfaces: [WaylandInterfaceIR]) {
        name = protocolName
        interfaces = protocolInterfaces
    }
}

/// One interface declared by a Wayland protocol.
public struct WaylandInterfaceIR: Codable, Equatable, Sendable {
    /// The wire interface name.
    public let name: String

    /// The highest version declared by the XML.
    public let version: UInt32

    /// Requests in opcode order.
    public let requests: [WaylandMessageIR]

    /// Events in opcode order.
    public let events: [WaylandMessageIR]

    /// Enumerations in source order.
    public let enumerations: [WaylandEnumerationIR]

    /// Creates an interface schema value.
    public init(
        name interfaceName: String,
        version interfaceVersion: UInt32,
        requests interfaceRequests: [WaylandMessageIR],
        events interfaceEvents: [WaylandMessageIR],
        enumerations interfaceEnumerations: [WaylandEnumerationIR]
    ) {
        name = interfaceName
        version = interfaceVersion
        requests = interfaceRequests
        events = interfaceEvents
        enumerations = interfaceEnumerations
    }
}

/// A request or event declared by a Wayland interface.
public struct WaylandMessageIR: Codable, Equatable, Sendable {
    /// The wire message name.
    public let name: String

    /// The zero-based opcode within the request or event list.
    public let opcode: UInt32

    /// The interface version that introduced the message.
    public let since: UInt32

    /// The interface version that deprecated the message, when declared.
    public let deprecatedSince: UInt32?

    /// Whether handling the message destroys the protocol object.
    public let isDestructor: Bool

    /// Message arguments in wire order.
    public let arguments: [WaylandArgumentIR]

    /// Creates a request or event schema value.
    public init(
        name messageName: String,
        opcode messageOpcode: UInt32,
        since messageSince: UInt32,
        deprecatedSince messageDeprecatedSince: UInt32?,
        isDestructor messageIsDestructor: Bool,
        arguments messageArguments: [WaylandArgumentIR]
    ) {
        name = messageName
        opcode = messageOpcode
        since = messageSince
        deprecatedSince = messageDeprecatedSince
        isDestructor = messageIsDestructor
        arguments = messageArguments
    }
}

/// One argument in a Wayland request or event.
public struct WaylandArgumentIR: Codable, Equatable, Sendable {
    /// The argument name.
    public let name: String

    /// The argument's wire representation.
    public let wireType: WaylandWireType

    /// The referenced object interface for object and `new_id` arguments.
    public let interfaceName: String?

    /// The referenced enumeration, which may be local or interface-qualified.
    public let enumerationName: String?

    /// Whether the protocol permits a null object or string value.
    public let isNullable: Bool

    /// Creates an argument schema value.
    public init(
        name argumentName: String,
        wireType argumentWireType: WaylandWireType,
        interfaceName argumentInterfaceName: String?,
        enumerationName argumentEnumerationName: String?,
        isNullable argumentIsNullable: Bool
    ) {
        name = argumentName
        wireType = argumentWireType
        interfaceName = argumentInterfaceName
        enumerationName = argumentEnumerationName
        isNullable = argumentIsNullable
    }
}

/// A wire type accepted by Wayland protocol XML.
public enum WaylandWireType: String, Codable, Equatable, Sendable {
    /// A signed 32-bit integer.
    case int

    /// An unsigned 32-bit integer.
    case uint

    /// A signed 24.8 fixed-point number.
    case fixed

    /// A UTF-8 string.
    case string

    /// An existing protocol object.
    case object

    /// A newly created protocol object.
    case newID = "new_id"

    /// An untyped byte array.
    case array

    /// A file descriptor transferred with the message.
    case fileDescriptor = "fd"
}

/// An enumeration declared by a Wayland interface.
public struct WaylandEnumerationIR: Codable, Equatable, Sendable {
    /// The enumeration name.
    public let name: String

    /// The interface version that introduced the enumeration.
    public let since: UInt32

    /// Whether entries may be combined as a bit field.
    public let isBitfield: Bool

    /// Entries in source order.
    public let entries: [WaylandEnumerationEntryIR]

    /// Creates an enumeration schema value.
    public init(
        name enumerationName: String,
        since enumerationSince: UInt32,
        isBitfield enumerationIsBitfield: Bool,
        entries enumerationEntries: [WaylandEnumerationEntryIR]
    ) {
        name = enumerationName
        since = enumerationSince
        isBitfield = enumerationIsBitfield
        entries = enumerationEntries
    }
}

/// One named value in a Wayland enumeration.
public struct WaylandEnumerationEntryIR: Codable, Equatable, Sendable {
    /// The entry name.
    public let name: String

    /// The exact decimal or hexadecimal value from the XML.
    public let rawValue: String

    /// The interface version that introduced the entry.
    public let since: UInt32

    /// The interface version that deprecated the entry, when declared.
    public let deprecatedSince: UInt32?

    /// Creates an enumeration entry schema value.
    public init(
        name entryName: String,
        rawValue entryRawValue: String,
        since entrySince: UInt32,
        deprecatedSince entryDeprecatedSince: UInt32?
    ) {
        name = entryName
        rawValue = entryRawValue
        since = entrySince
        deprecatedSince = entryDeprecatedSince
    }
}

/// Client choices that can be layered over facts parsed from Wayland XML.
public struct WaylandProtocolGenerationPolicy: Codable, Equatable, Sendable {
    /// Per-interface generation choices keyed by wire interface name.
    public let interfaces: [String: WaylandInterfaceGenerationPolicy]

    /// Creates a policy overlay.
    public init(interfaces interfacePolicies: [String: WaylandInterfaceGenerationPolicy]) {
        interfaces = interfacePolicies
    }

    /// Checks that every policy entry names a parsed interface and uses supported versions.
    public func validate(against protocols: [WaylandProtocolIR]) throws {
        var interfacesByName: [String: WaylandInterfaceIR] = [:]
        for interface in protocols.flatMap(\.interfaces) {
            guard interfacesByName.updateValue(interface, forKey: interface.name) == nil else {
                throw ToolError(
                    "Wayland XML declares interface more than once: \(interface.name)",
                    exitCode: ToolExitCode.data
                )
            }
        }

        for name in interfaces.keys.sorted() {
            guard let policy = interfaces[name] else { continue }
            guard let interface = interfacesByName[name] else {
                throw ToolError(
                    "protocol generation policy references unknown interface: \(name)",
                    exitCode: ToolExitCode.data
                )
            }
            try validate(interfacePolicy: policy, named: name, against: interface)
        }

        try validateRetainedOptionalGlobals()
    }

    private func validate(
        interfacePolicy policy: WaylandInterfaceGenerationPolicy,
        named name: String,
        against interface: WaylandInterfaceIR
    ) throws {
        guard policy.maximumSupportedVersion > 0 else {
            throw ToolError(
                "\(name) maximumSupportedVersion must be greater than zero",
                exitCode: ToolExitCode.data
            )
        }
        guard policy.maximumSupportedVersion <= interface.version else {
            throw ToolError(
                "\(name) maximumSupportedVersion \(policy.maximumSupportedVersion) exceeds "
                    + "XML version \(interface.version)",
                exitCode: ToolExitCode.data
            )
        }
        if let minimumRequiredVersion = policy.minimumRequiredVersion {
            guard minimumRequiredVersion > 0 else {
                throw ToolError(
                    "\(name) minimumRequiredVersion must be greater than zero",
                    exitCode: ToolExitCode.data
                )
            }
            guard minimumRequiredVersion <= policy.maximumSupportedVersion else {
                throw ToolError(
                    "\(name) minimumRequiredVersion \(minimumRequiredVersion) exceeds "
                        + "maximumSupportedVersion \(policy.maximumSupportedVersion)",
                    exitCode: ToolExitCode.data
                )
            }
        }
        if policy.reportsCapability, policy.globalBinding != .optional {
            throw ToolError(
                "\(name) reportsCapability requires optional globalBinding",
                exitCode: ToolExitCode.data
            )
        }
    }

    private func validateRetainedOptionalGlobals() throws {
        let retainedGlobals = interfaces.compactMap { interfaceName, interfacePolicy in
            interfacePolicy.retainedOptionalGlobal.map { (interfaceName, interfacePolicy, $0) }
        }
        var propertyNames: Set<String> = []
        var bindingMethodNames: Set<String> = []
        var bindingOrders: Set<UInt32> = []

        for (interfaceName, interfacePolicy, retainedGlobal) in retainedGlobals {
            guard interfacePolicy.globalBinding == .optional else {
                throw ToolError(
                    "\(interfaceName) retainedOptionalGlobal requires optional globalBinding",
                    exitCode: ToolExitCode.data
                )
            }
            try validateRetainedNames(retainedGlobal, interfaceName: interfaceName)
            guard propertyNames.insert(retainedGlobal.propertyName).inserted else {
                throw ToolError(
                    "retained optional globals use property more than once: "
                        + retainedGlobal.propertyName,
                    exitCode: ToolExitCode.data
                )
            }
            guard bindingMethodNames.insert(retainedGlobal.bindingMethodName).inserted else {
                throw ToolError(
                    "retained optional globals use binding method more than once: "
                        + retainedGlobal.bindingMethodName,
                    exitCode: ToolExitCode.data
                )
            }
            guard bindingOrders.insert(retainedGlobal.bindingOrder).inserted else {
                throw ToolError(
                    "retained optional globals use binding order more than once: "
                        + String(retainedGlobal.bindingOrder),
                    exitCode: ToolExitCode.data
                )
            }
        }

        for (expectedOrder, retainedGlobal)
            in retainedGlobals
            .map(\.2)
            .sorted(by: { $0.bindingOrder < $1.bindingOrder })
            .enumerated()
        where retainedGlobal.bindingOrder != UInt32(expectedOrder) {
            throw ToolError(
                "retained optional-global binding order must be contiguous from zero",
                exitCode: ToolExitCode.data
            )
        }
    }

    private func validateRetainedNames(
        _ retainedGlobal: WaylandRetainedOptionalGlobalPolicy,
        interfaceName: String
    ) throws {
        let names = [
            ("property name", retainedGlobal.propertyName),
            ("binding method", retainedGlobal.bindingMethodName),
            ("wrapper type", retainedGlobal.wrapperTypeName),
        ]
        for (label, name) in names where !Self.isSwiftIdentifier(name) {
            throw ToolError(
                "\(interfaceName) has invalid retained optional-global \(label): \(name)",
                exitCode: ToolExitCode.data
            )
        }
    }

    private static func isSwiftIdentifier(_ value: String) -> Bool {
        guard let first = value.first, first.isLetter || first == "_" else {
            return false
        }
        return value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}

/// Client-specific generation choices for one Wayland interface.
public struct WaylandInterfaceGenerationPolicy: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case maximumSupportedVersion
        case minimumRequiredVersion
        case globalBinding
        case reportsCapability
        case retainedOptionalGlobal
    }

    /// The highest interface version implemented by the client.
    public let maximumSupportedVersion: UInt32

    /// The oldest advertised version the client can bind, when one is required.
    public let minimumRequiredVersion: UInt32?

    /// How the interface participates in registry binding, when it is a global.
    public let globalBinding: WaylandGlobalBindingPolicy?

    /// Whether the public display capability inventory reports this optional global.
    public let reportsCapability: Bool

    /// The owned optional-global slot generated for this interface, when retained.
    public let retainedOptionalGlobal: WaylandRetainedOptionalGlobalPolicy?

    /// Creates an interface policy value.
    public init(
        maximumSupportedVersion interfaceMaximumSupportedVersion: UInt32,
        minimumRequiredVersion interfaceMinimumRequiredVersion: UInt32? = nil,
        globalBinding interfaceGlobalBinding: WaylandGlobalBindingPolicy? = nil,
        reportsCapability interfaceReportsCapability: Bool = false,
        retainedOptionalGlobal interfaceRetainedOptionalGlobal:
            WaylandRetainedOptionalGlobalPolicy? = nil
    ) {
        maximumSupportedVersion = interfaceMaximumSupportedVersion
        minimumRequiredVersion = interfaceMinimumRequiredVersion
        globalBinding = interfaceGlobalBinding
        reportsCapability = interfaceReportsCapability
        retainedOptionalGlobal = interfaceRetainedOptionalGlobal
    }

    /// Decodes an interface policy, treating an omitted capability flag as false.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maximumSupportedVersion = try container.decode(
            UInt32.self,
            forKey: .maximumSupportedVersion
        )
        minimumRequiredVersion = try container.decodeIfPresent(
            UInt32.self,
            forKey: .minimumRequiredVersion
        )
        globalBinding = try container.decodeIfPresent(
            WaylandGlobalBindingPolicy.self,
            forKey: .globalBinding
        )
        reportsCapability =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .reportsCapability
            ) ?? false
        retainedOptionalGlobal = try container.decodeIfPresent(
            WaylandRetainedOptionalGlobalPolicy.self,
            forKey: .retainedOptionalGlobal
        )
    }

    /// Encodes the interface policy without writing the default capability flag.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(maximumSupportedVersion, forKey: .maximumSupportedVersion)
        try container.encodeIfPresent(
            minimumRequiredVersion,
            forKey: .minimumRequiredVersion
        )
        try container.encodeIfPresent(globalBinding, forKey: .globalBinding)
        if reportsCapability {
            try container.encode(true, forKey: .reportsCapability)
        }
        try container.encodeIfPresent(
            retainedOptionalGlobal,
            forKey: .retainedOptionalGlobal
        )
    }
}

/// Generation details for an optional global owned by `OptionalGlobals`.
public struct WaylandRetainedOptionalGlobalPolicy: Codable, Equatable, Sendable {
    /// The `OptionalGlobals` property that owns the raw wrapper.
    public let propertyName: String

    /// The handwritten raw binding method called by generated orchestration.
    public let bindingMethodName: String

    /// The optional wrapper stored in `OptionalGlobals`.
    public let wrapperTypeName: String

    /// The acquisition position used to generate rollback and reverse destruction.
    public let bindingOrder: UInt32

    /// Creates retained optional-global generation details.
    public init(
        propertyName: String,
        bindingMethodName: String,
        wrapperTypeName: String,
        bindingOrder: UInt32
    ) {
        self.propertyName = propertyName
        self.bindingMethodName = bindingMethodName
        self.wrapperTypeName = wrapperTypeName
        self.bindingOrder = bindingOrder
    }
}

/// The client's registry-binding treatment for a global interface.
public enum WaylandGlobalBindingPolicy: String, Codable, Equatable, Sendable {
    /// Generation treats absence of the global as a binding failure.
    case required

    /// Generation allows the client to continue when the global is absent.
    case optional
}
