import Foundation
import FoundationXML

/// Parses Wayland protocol XML into a deterministic schema model.
public struct WaylandProtocolXMLParser: Sendable {
    /// Creates a protocol XML parser.
    public init() {
        // Parsing has no shared mutable state.
    }

    /// Parses XML data and labels any error with the supplied source name.
    public func parse(
        _ data: Data,
        source sourceName: String = "<memory>"
    ) throws -> WaylandProtocolIR {
        let delegate = ProtocolXMLDelegate(source: sourceName)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false

        let succeeded = parser.parse()
        if let failure = delegate.failure {
            throw failure
        }
        guard succeeded else {
            throw WaylandProtocolXMLParserError(
                source: sourceName,
                line: parser.lineNumber,
                column: parser.columnNumber,
                message: parser.parserError?.localizedDescription ?? "malformed XML"
            )
        }

        return try delegate.finish()
    }
}

final class ProtocolXMLDelegate: NSObject, XMLParserDelegate {
    private let source: String
    private var protocolName: String?
    private var interfaces: [WaylandInterfaceIR] = []
    private var interface: InterfaceBuilder?
    private var message: MessageBuilder?
    private var enumeration: EnumerationBuilder?
    private(set) var failure: WaylandProtocolXMLParserError?

    init(source sourceName: String) {
        source = sourceName
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard failure == nil else { return }

        switch elementName {
        case "protocol":
            startProtocol(attributes: attributeDict, parser: parser)
        case "interface":
            startInterface(attributes: attributeDict, parser: parser)
        case MessageKind.request.rawValue, MessageKind.event.rawValue:
            startMessage(elementName, attributes: attributeDict, parser: parser)
        case "arg":
            appendArgument(attributes: attributeDict, parser: parser)
        case "enum":
            startEnumeration(attributes: attributeDict, parser: parser)
        case "entry":
            appendEnumerationEntry(attributes: attributeDict, parser: parser)
        case "copyright", "description":
            return
        default:
            fail("unsupported Wayland XML element <\(elementName)>", parser: parser)
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        guard failure == nil else { return }

        switch elementName {
        case MessageKind.request.rawValue, MessageKind.event.rawValue:
            finishMessage(elementName, parser: parser)
        case "enum":
            finishEnumeration(parser: parser)
        case "interface":
            finishInterface(parser: parser)
        case "protocol", "arg", "entry", "copyright", "description":
            return
        default:
            fail("unsupported Wayland XML element </\(elementName)>", parser: parser)
        }
    }

    func finish() throws -> WaylandProtocolIR {
        guard let protocolName else {
            throw WaylandProtocolXMLParserError(
                source: source,
                line: 1,
                column: 1,
                message: "missing <protocol> root element"
            )
        }
        guard interface == nil, message == nil, enumeration == nil else {
            throw WaylandProtocolXMLParserError(
                source: source,
                line: 1,
                column: 1,
                message: "Wayland XML ended with an incomplete declaration"
            )
        }

        return WaylandProtocolIR(name: protocolName, interfaces: interfaces)
    }
}

extension ProtocolXMLDelegate {
    private func startProtocol(attributes: [String: String], parser: XMLParser) {
        guard protocolName == nil else {
            fail("Wayland XML contains more than one <protocol> element", parser: parser)
            return
        }
        guard
            let name = requiredAttribute(
                "name", in: attributes, element: "protocol", parser: parser)
        else {
            return
        }

        protocolName = name
    }

    private func startInterface(attributes: [String: String], parser: XMLParser) {
        guard protocolName != nil else {
            fail("<interface> must be inside <protocol>", parser: parser)
            return
        }
        guard interface == nil, message == nil, enumeration == nil else {
            fail("nested <interface> declarations are not supported", parser: parser)
            return
        }
        guard
            let name = requiredAttribute(
                "name", in: attributes, element: "interface", parser: parser),
            let version = positiveUInt32Attribute(
                "version",
                in: attributes,
                element: "interface",
                defaultValue: nil,
                parser: parser
            )
        else {
            return
        }

        interface = InterfaceBuilder(name: name, version: version)
    }

    private func startMessage(
        _ elementName: String,
        attributes: [String: String],
        parser: XMLParser
    ) {
        guard let kind = MessageKind(rawValue: elementName), let interface else {
            fail("<\(elementName)> must be inside <interface>", parser: parser)
            return
        }
        guard message == nil, enumeration == nil else {
            fail("nested <\(elementName)> declarations are not supported", parser: parser)
            return
        }
        guard
            let name = requiredAttribute(
                "name", in: attributes, element: elementName, parser: parser),
            let since = positiveUInt32Attribute(
                "since",
                in: attributes,
                element: elementName,
                defaultValue: 1,
                parser: parser
            ),
            let deprecatedSince = optionalPositiveUInt32Attribute(
                "deprecated-since",
                in: attributes,
                element: elementName,
                parser: parser
            )
        else {
            return
        }

        let isDestructor: Bool
        switch attributes["type"] {
        case nil:
            isDestructor = false
        case "destructor":
            isDestructor = true
        case .some(let value):
            fail("<\(elementName)> has unsupported type \"\(value)\"", parser: parser)
            return
        }

        let count = kind == .request ? interface.requests.count : interface.events.count
        guard let opcode = UInt32(exactly: count) else {
            fail("<interface> has too many \(elementName) declarations", parser: parser)
            return
        }

        message = MessageBuilder(
            kind: kind,
            name: name,
            opcode: opcode,
            since: since,
            deprecatedSince: deprecatedSince,
            isDestructor: isDestructor
        )
    }

    private func appendArgument(attributes: [String: String], parser: XMLParser) {
        guard var message, enumeration == nil else {
            fail("<arg> must be inside <request> or <event>", parser: parser)
            return
        }
        guard
            let name = requiredAttribute("name", in: attributes, element: "arg", parser: parser),
            let rawType = requiredAttribute("type", in: attributes, element: "arg", parser: parser)
        else {
            return
        }
        guard let wireType = WaylandWireType(rawValue: rawType) else {
            fail("<arg> has unsupported wire type \"\(rawType)\"", parser: parser)
            return
        }
        let isNullableResult = booleanAttribute(
            "allow-null",
            in: attributes,
            element: "arg",
            defaultValue: false,
            parser: parser
        )
        guard case .value(let isNullable) = isNullableResult else {
            return
        }

        message.arguments.append(
            WaylandArgumentIR(
                name: name,
                wireType: wireType,
                interfaceName: attributes["interface"],
                enumerationName: attributes["enum"],
                isNullable: isNullable
            )
        )
        self.message = message
    }
}

extension ProtocolXMLDelegate {
    private func startEnumeration(attributes: [String: String], parser: XMLParser) {
        guard interface != nil, message == nil, enumeration == nil else {
            fail("<enum> must be directly inside <interface>", parser: parser)
            return
        }
        guard
            let name = requiredAttribute("name", in: attributes, element: "enum", parser: parser),
            let since = positiveUInt32Attribute(
                "since",
                in: attributes,
                element: "enum",
                defaultValue: 1,
                parser: parser
            )
        else {
            return
        }
        let isBitfieldResult = booleanAttribute(
            "bitfield",
            in: attributes,
            element: "enum",
            defaultValue: false,
            parser: parser
        )
        guard case .value(let isBitfield) = isBitfieldResult else {
            return
        }

        enumeration = EnumerationBuilder(name: name, since: since, isBitfield: isBitfield)
    }

    private func appendEnumerationEntry(attributes: [String: String], parser: XMLParser) {
        guard var enumeration, message == nil else {
            fail("<entry> must be inside <enum>", parser: parser)
            return
        }
        guard
            let name = requiredAttribute("name", in: attributes, element: "entry", parser: parser),
            let rawValue = requiredAttribute(
                "value", in: attributes, element: "entry", parser: parser),
            let since = positiveUInt32Attribute(
                "since",
                in: attributes,
                element: "entry",
                defaultValue: 1,
                parser: parser
            ),
            let deprecatedSince = optionalPositiveUInt32Attribute(
                "deprecated-since",
                in: attributes,
                element: "entry",
                parser: parser
            )
        else {
            return
        }

        enumeration.entries.append(
            WaylandEnumerationEntryIR(
                name: name,
                rawValue: rawValue,
                since: since,
                deprecatedSince: deprecatedSince
            )
        )
        self.enumeration = enumeration
    }

    private func finishMessage(_ elementName: String, parser: XMLParser) {
        guard let message, message.kind.rawValue == elementName, var interface else {
            fail("unexpected </\(elementName)>", parser: parser)
            return
        }

        switch message.kind {
        case .request:
            interface.requests.append(message.value)
        case .event:
            interface.events.append(message.value)
        }
        self.interface = interface
        self.message = nil
    }

    private func finishEnumeration(parser: XMLParser) {
        guard let enumeration, var interface, message == nil else {
            fail("unexpected </enum>", parser: parser)
            return
        }

        interface.enumerations.append(enumeration.value)
        self.interface = interface
        self.enumeration = nil
    }

    private func finishInterface(parser: XMLParser) {
        guard let interface, message == nil, enumeration == nil else {
            fail("unexpected </interface>", parser: parser)
            return
        }

        interfaces.append(
            WaylandInterfaceIR(
                name: interface.name,
                version: interface.version,
                requests: interface.requests,
                events: interface.events,
                enumerations: interface.enumerations
            )
        )
        self.interface = nil
    }
}

extension ProtocolXMLDelegate {
    private func requiredAttribute(
        _ name: String,
        in attributes: [String: String],
        element: String,
        parser: XMLParser
    ) -> String? {
        guard let value = attributes[name], !value.isEmpty else {
            fail("<\(element)> is missing required \(name) attribute", parser: parser)
            return nil
        }

        return value
    }

    private func positiveUInt32Attribute(
        _ name: String,
        in attributes: [String: String],
        element: String,
        defaultValue: UInt32?,
        parser: XMLParser
    ) -> UInt32? {
        guard let rawValue = attributes[name] else {
            if let defaultValue {
                return defaultValue
            }
            fail("<\(element)> is missing required \(name) attribute", parser: parser)
            return nil
        }
        guard let value = UInt32(rawValue), value > 0 else {
            fail("<\(element)> has invalid \(name) value \"\(rawValue)\"", parser: parser)
            return nil
        }

        return value
    }

    private func optionalPositiveUInt32Attribute(
        _ name: String,
        in attributes: [String: String],
        element: String,
        parser: XMLParser
    ) -> UInt32?? {
        guard let rawValue = attributes[name] else {
            return .some(nil)
        }
        guard let value = UInt32(rawValue), value > 0 else {
            fail("<\(element)> has invalid \(name) value \"\(rawValue)\"", parser: parser)
            return nil
        }

        return .some(value)
    }

    private func booleanAttribute(
        _ name: String,
        in attributes: [String: String],
        element: String,
        defaultValue: Bool,
        parser: XMLParser
    ) -> BooleanAttributeParseResult {
        guard let rawValue = attributes[name] else {
            return .value(defaultValue)
        }
        switch rawValue {
        case "true":
            return .value(true)
        case "false":
            return .value(false)
        default:
            fail("<\(element)> has invalid \(name) value \"\(rawValue)\"", parser: parser)
            return .invalid
        }
    }

    private func fail(_ message: String, parser: XMLParser) {
        guard failure == nil else { return }

        failure = WaylandProtocolXMLParserError(
            source: source,
            line: parser.lineNumber,
            column: parser.columnNumber,
            message: message
        )
        parser.abortParsing()
    }
}
