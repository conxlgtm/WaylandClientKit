extension ProtocolXMLDelegate {
    enum MessageKind: String {
        case request
        case event
    }

    struct InterfaceBuilder {
        let name: String
        let version: UInt32
        var requests: [WaylandMessageIR] = []
        var events: [WaylandMessageIR] = []
        var enumerations: [WaylandEnumerationIR] = []
    }

    struct MessageBuilder {
        let kind: MessageKind
        let name: String
        let opcode: UInt32
        let since: UInt32
        let deprecatedSince: UInt32?
        let isDestructor: Bool
        var arguments: [WaylandArgumentIR] = []

        var value: WaylandMessageIR {
            WaylandMessageIR(
                name: name,
                opcode: opcode,
                since: since,
                deprecatedSince: deprecatedSince,
                isDestructor: isDestructor,
                arguments: arguments
            )
        }
    }

    struct EnumerationBuilder {
        let name: String
        let since: UInt32
        let isBitfield: Bool
        var entries: [WaylandEnumerationEntryIR] = []

        var value: WaylandEnumerationIR {
            WaylandEnumerationIR(
                name: name,
                since: since,
                isBitfield: isBitfield,
                entries: entries
            )
        }
    }

    enum BooleanAttributeParseResult {
        case value(Bool)
        case invalid
    }
}
