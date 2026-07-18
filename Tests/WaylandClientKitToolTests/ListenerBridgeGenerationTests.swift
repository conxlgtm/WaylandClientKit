import Foundation
import Testing

@testable import WaylandClientKitToolSupport

@Suite
struct ListenerBridgeGenerationTests {
    @Test
    func checkedInListenerBridgesMatchStableRendererOutput() throws {
        let tooling = ProtocolTooling(repository: Repository(root: repositoryRoot))
        let first = try tooling.renderListenerBridgeArtifacts()
        let second = try tooling.renderListenerBridgeArtifacts()
        let checkedInHeader = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                ListenerBridgeGeneration.headerOutputPath
            ),
            encoding: .utf8
        )
        let checkedInSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                ListenerBridgeGeneration.sourceOutputPath
            ),
            encoding: .utf8
        )

        #expect(first == second)
        #expect(first.header == checkedInHeader)
        #expect(first.source == checkedInSource)
    }

    @Test
    func checkedPolicyKeepsTheHandwrittenPartitionAndNamingExceptions() throws {
        let tooling = ProtocolTooling(repository: Repository(root: repositoryRoot))
        let policy = try tooling.loadListenerBridgePolicy()
        let handwritten = policy.interfaces.compactMap { interfaceName, bridge in
            bridge.forwarding == .handwritten ? interfaceName : nil
        }

        #expect(policy.interfaces.count == 52)
        #expect(policy.interfaces.values.filter { $0.forwarding == .generated }.count == 43)
        #expect(
            Set(handwritten)
                == Set([
                    "wl_buffer",
                    "wl_output",
                    "wl_surface",
                    "wp_color_manager_v1",
                    "wp_color_representation_manager_v1",
                    "wp_image_description_v1",
                    "wp_presentation",
                    "wp_presentation_feedback",
                    "zwp_keyboard_shortcuts_inhibitor_v1",
                ])
        )
        #expect(
            policy.interfaces["wl_surface"]?.omittedEvents
                == ["preferred_buffer_transform"]
        )
        #expect(
            policy.interfaces["xdg_popup"]?.callbackName(for: "popup_done") == "done"
        )
        #expect(
            policy.interfaces["zwp_linux_dmabuf_feedback_v1"]?.effectiveInstallerPrefix
                == "zwp_linux_dmabuf_feedback_v1"
        )
    }

    @Test
    func rendererKeepsEventOrderAndMapsEveryCWireType() throws {
        let bridge = ResolvedListenerBridge(
            interface: wireTypeInterface,
            policy: ListenerBridgeInterfacePolicy(
                callbackPrefix: "example_device_v1",
                forwarding: .generated
            ),
            generatedHeaderInclude: "generated/example/example-client-protocol.h"
        )
        let header = ListenerBridgeHeaderRenderer.render(bridges: [bridge])
        let source = ListenerBridgeSourceRenderer.render(bridges: [bridge])

        #expect(header.contains("int32_t event_signed_value"))
        #expect(header.contains("uint32_t event_unsigned_value"))
        #expect(header.contains("wl_fixed_t event_coordinate"))
        #expect(header.contains("const char *event_title"))
        #expect(header.contains("struct example_peer_v1 *event_peer"))
        #expect(header.contains("struct example_child_v1 *event_child"))
        #expect(header.contains("struct wl_array *event_bytes"))
        #expect(header.contains("int32_t event_descriptor"))
        #expect(
            try sourceIndex(of: ".first =", in: source)
                < sourceIndex(of: ".second =", in: source)
        )
        #expect(
            source.contains(
                "#include \"generated/example/example-client-protocol.h\""
            )
        )
    }

    @Test
    func rendererLeavesCheckedOmittedEventsOutOfTheBundle() {
        let bridge = ResolvedListenerBridge(
            interface: wireTypeInterface,
            policy: ListenerBridgeInterfacePolicy(
                callbackPrefix: "example_device_v1",
                forwarding: .handwritten,
                omittedEvents: ["second"]
            ),
            generatedHeaderInclude: nil
        )
        let header = ListenerBridgeHeaderRenderer.render(bridges: [bridge])
        let source = ListenerBridgeSourceRenderer.render(bridges: [bridge])

        #expect(header.contains("swl_example_device_v1_first_fn first;"))
        #expect(!header.contains("swl_example_device_v1_second_fn"))
        #expect(!source.contains("example_device_v1_add_listener"))
    }

    @Test
    func policyRejectsUnknownOmittedEvents() {
        let policy = ListenerBridgePolicy(
            interfaces: [
                "example_device_v1": ListenerBridgeInterfacePolicy(
                    callbackPrefix: "example_device_v1",
                    forwarding: .generated,
                    omittedEvents: ["missing"]
                )
            ]
        )

        #expect(throws: ToolError.self) {
            try policy.validate(against: [fixtureProtocol])
        }
    }

    @Test
    func policyRejectsDuplicateCallbackPrefixes() {
        let policy = ListenerBridgePolicy(
            interfaces: [
                "example_device_v1": ListenerBridgeInterfacePolicy(
                    callbackPrefix: "duplicate",
                    forwarding: .generated
                ),
                "example_peer_v1": ListenerBridgeInterfacePolicy(
                    callbackPrefix: "duplicate",
                    forwarding: .generated
                ),
            ]
        )

        #expect(throws: ToolError.self) {
            try policy.validate(against: [fixtureProtocol])
        }
    }

    private func sourceIndex(of text: String, in source: String) throws -> String.Index {
        try #require(source.range(of: text)?.lowerBound)
    }

    private var fixtureProtocol: WaylandProtocolIR {
        WaylandProtocolIR(
            name: "example",
            interfaces: [
                wireTypeInterface,
                WaylandInterfaceIR(
                    name: "example_peer_v1",
                    version: 1,
                    requests: [],
                    events: [
                        WaylandMessageIR(
                            name: "changed",
                            opcode: 0,
                            since: 1,
                            deprecatedSince: nil,
                            isDestructor: false,
                            arguments: []
                        )
                    ],
                    enumerations: []
                ),
            ]
        )
    }

    private var wireTypeInterface: WaylandInterfaceIR {
        WaylandInterfaceIR(
            name: "example_device_v1",
            version: 1,
            requests: [],
            events: [
                WaylandMessageIR(
                    name: "first",
                    opcode: 0,
                    since: 1,
                    deprecatedSince: nil,
                    isDestructor: false,
                    arguments: wireTypeArguments
                ),
                WaylandMessageIR(
                    name: "second",
                    opcode: 1,
                    since: 1,
                    deprecatedSince: nil,
                    isDestructor: false,
                    arguments: []
                ),
            ],
            enumerations: []
        )
    }

    private var wireTypeArguments: [WaylandArgumentIR] {
        [
            argument("signed_value", type: .int),
            argument("unsigned_value", type: .uint),
            argument("coordinate", type: .fixed),
            argument("title", type: .string),
            argument("peer", type: .object, interfaceName: "example_peer_v1"),
            argument("child", type: .newID, interfaceName: "example_child_v1"),
            argument("bytes", type: .array),
            argument("descriptor", type: .fileDescriptor),
        ]
    }

    private func argument(
        _ name: String,
        type: WaylandWireType,
        interfaceName: String? = nil
    ) -> WaylandArgumentIR {
        WaylandArgumentIR(
            name: name,
            wireType: type,
            interfaceName: interfaceName,
            enumerationName: nil,
            isNullable: false
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
