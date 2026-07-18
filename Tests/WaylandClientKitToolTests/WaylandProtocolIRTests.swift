import Foundation
import Testing
import WaylandClientKitToolSupport

@Suite
struct WaylandProtocolIRTests {
    @Test
    func parserMatchesCanonicalFixture() throws {
        let protocolIR = try parseFixture()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let data = try encoder.encode(protocolIR)
        let actual = try #require(String(data: data, encoding: .utf8)) + "\n"
        let expected = try String(contentsOf: fixture("example-ir.json"), encoding: .utf8)

        #expect(actual == expected)
    }

    @Test
    func parserPreservesWireOrderAndMessageMetadata() throws {
        let protocolIR = try parseFixture()
        let manager = try #require(protocolIR.interfaces.first)

        #expect(protocolIR.name == "example_v1")
        #expect(protocolIR.interfaces.map(\.name) == ["example_manager_v1", "example_item_v1"])
        #expect(manager.requests.map(\.opcode) == [0, 1])
        #expect(manager.requests[0].isDestructor)
        #expect(manager.requests[1].arguments.map(\.wireType) == [.newID, .object])
        #expect(manager.requests[1].arguments[1].isNullable)
        #expect(manager.events[0].arguments[0].enumerationName == "flags")
        #expect(manager.enumerations[0].isBitfield)
        #expect(manager.enumerations[0].entries.map(\.rawValue) == ["0x1", "0x2"])
        #expect(manager.enumerations[0].entries[1].deprecatedSince == 4)
    }

    @Test
    func policyOverlayDecodesAndValidatesAgainstXML() throws {
        let data = try Data(contentsOf: fixture("example-policy.json"))
        let policy = try JSONDecoder().decode(WaylandProtocolGenerationPolicy.self, from: data)

        try policy.validate(against: [parseFixture()])

        let manager = try #require(policy.interfaces["example_manager_v1"])
        #expect(manager.maximumSupportedVersion == 2)
        #expect(manager.minimumRequiredVersion == 1)
        #expect(manager.globalBinding == .optional)
        #expect(manager.reportsCapability)
        #expect(manager.retainedOptionalGlobal?.propertyName == "exampleManager")
        #expect(manager.retainedOptionalGlobal?.wrapperTypeName == "OptionalExampleManager")
    }

    @Test
    func policyOverlayRejectsVersionAboveXML() throws {
        let policy = WaylandProtocolGenerationPolicy(
            interfaces: [
                "example_manager_v1": WaylandInterfaceGenerationPolicy(
                    maximumSupportedVersion: 4,
                    globalBinding: .optional
                )
            ]
        )

        do {
            try policy.validate(against: [parseFixture()])
            Issue.record("expected policy validation to reject a version above the XML")
        } catch let error as ToolError {
            #expect(error.message.contains("maximumSupportedVersion 4 exceeds XML version 3"))
        }
    }

    @Test
    func policyOverlayRejectsCapabilityReportingForRequiredGlobal() throws {
        let policy = WaylandProtocolGenerationPolicy(
            interfaces: [
                "example_manager_v1": WaylandInterfaceGenerationPolicy(
                    maximumSupportedVersion: 2,
                    globalBinding: .required,
                    reportsCapability: true
                )
            ]
        )

        do {
            try policy.validate(against: [parseFixture()])
            Issue.record("expected policy validation to reject required capability reporting")
        } catch let error as ToolError {
            #expect(error.message.contains("reportsCapability requires optional globalBinding"))
        }
    }

    @Test
    func policyOverlayRejectsNoncontiguousRetainedBindingOrder() throws {
        let policy = WaylandProtocolGenerationPolicy(
            interfaces: [
                "example_manager_v1": WaylandInterfaceGenerationPolicy(
                    maximumSupportedVersion: 2,
                    globalBinding: .optional,
                    retainedOptionalGlobal: WaylandRetainedOptionalGlobalPolicy(
                        propertyName: "exampleManager",
                        bindingMethodName: "bindExampleManagerIfPresent",
                        wrapperTypeName: "OptionalExampleManager",
                        bindingOrder: 1
                    )
                )
            ]
        )

        do {
            try policy.validate(against: [parseFixture()])
            Issue.record("expected policy validation to reject a binding-order gap")
        } catch let error as ToolError {
            #expect(
                error.message.contains(
                    "retained optional-global binding order must be contiguous from zero"
                )
            )
        }
    }

    @Test
    func parserReportsUnsupportedWireTypeWithSourceLocation() throws {
        let data = Data(
            """
            <protocol name="broken">
              <interface name="broken_v1" version="1">
                <event name="broken"><arg name="value" type="pointer"/></event>
              </interface>
            </protocol>
            """.utf8
        )

        do {
            _ = try WaylandProtocolXMLParser().parse(data, source: "broken.xml")
            Issue.record("expected parser to reject an unknown wire type")
        } catch let error as WaylandProtocolXMLParserError {
            #expect(error.source == "broken.xml")
            #expect(error.line == 3)
            #expect(error.message == "<arg> has unsupported wire type \"pointer\"")
        }
    }

    @Test
    func protocolToolingParsesEveryVendoredXMLFileInManifestOrder() throws {
        let tooling = ProtocolTooling(repository: Repository(root: repositoryRoot))
        let entries = try tooling.loadManifest().protocols
        let protocolIRs = try tooling.loadProtocolIRs()

        #expect(protocolIRs.count == entries.count)
        #expect(protocolIRs.map(\.name).count == entries.count)
        #expect(protocolIRs.allSatisfy { !$0.name.isEmpty && !$0.interfaces.isEmpty })
    }

    @Test
    func checkedInSupportedVersionsMatchXMLAndGenerationPolicy() throws {
        let tooling = ProtocolTooling(repository: Repository(root: repositoryRoot))
        let expected = try tooling.renderSupportedVersions()
        let actual = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/WaylandRaw/Internal/Binding/SupportedVersions.swift"
            ),
            encoding: .utf8
        )

        #expect(actual == expected)
    }

    @Test
    func checkedInOptionalGlobalDescriptorsMatchXMLAndGenerationPolicy() throws {
        let tooling = ProtocolTooling(repository: Repository(root: repositoryRoot))
        let expected = try tooling.renderOptionalGlobalDescriptors()
        let actual = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/WaylandRaw/Internal/Binding/OptionalGlobalDescriptors.swift"
            ),
            encoding: .utf8
        )

        #expect(actual == expected)
    }

    @Test
    func generationPolicyRecordsCurrentGlobalBindingChoices() throws {
        let tooling = ProtocolTooling(repository: Repository(root: repositoryRoot))
        let policy = try tooling.loadGenerationPolicy()
        let required = policy.interfaces.compactMap { name, interfacePolicy in
            interfacePolicy.globalBinding == .required ? name : nil
        }
        let optional = policy.interfaces.values.filter { $0.globalBinding == .optional }
        let retained = policy.interfaces.values.compactMap(\.retainedOptionalGlobal)
        let capabilityReported = policy.interfaces.values.filter { interfacePolicy in
            interfacePolicy.reportsCapability
        }

        #expect(Set(required) == Set(["wl_compositor", "wl_shm", "xdg_wm_base"]))
        #expect(optional.count == 36)
        #expect(retained.count == 25)
        #expect(retained.map(\.bindingOrder).sorted() == (0..<25).map(UInt32.init))
        #expect(capabilityReported.count == 25)
        #expect(policy.interfaces["wl_seat"]?.minimumRequiredVersion == 5)
    }

    private func parseFixture() throws -> WaylandProtocolIR {
        try WaylandProtocolXMLParser().parse(
            Data(contentsOf: fixture("example.xml")),
            source: "example.xml"
        )
    }

    private func fixture(_ name: String) throws -> URL {
        try #require(
            Bundle.module.url(
                forResource: name,
                withExtension: nil,
                subdirectory: "Fixtures/ProtocolIR"
            )
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
