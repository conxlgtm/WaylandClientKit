import Foundation
import Testing

@testable import WaylandClientKitToolSupport

@Suite
struct RequestBridgeGenerationTests {
    @Test
    func checkedInRequestBridgesMatchStableRendererOutput() throws {
        let tooling = ProtocolTooling(repository: Repository(root: repositoryRoot))
        let first = try tooling.renderRequestBridgeArtifacts()
        let second = try tooling.renderRequestBridgeArtifacts()
        let checkedInHeader = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                RequestBridgeGeneration.headerOutputPath
            ),
            encoding: .utf8
        )
        let checkedInSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                RequestBridgeGeneration.sourceOutputPath
            ),
            encoding: .utf8
        )

        #expect(first == second)
        #expect(first.header == checkedInHeader)
        #expect(first.source == checkedInSource)
    }

    @Test
    func policyOwnsTheGeneratedInventoryAndExistingABINames() throws {
        let tooling = ProtocolTooling(repository: Repository(root: repositoryRoot))
        let policy = try tooling.loadRequestBridgePolicy()
        let bridges = try RequestBridgeGeneration.resolve(
            protocols: tooling.loadProtocolIRs(),
            manifest: tooling.loadManifest(),
            policy: policy
        )
        let names = Set(bridges.map(\.functionName))

        #expect(policy.interfaces.count == 38)
        #expect(bridges.count == 61)
        #expect(names.contains("swl_compositor_create_surface"))
        #expect(names.contains("swl_surface_frame"))
        #expect(names.contains("swl_seat_get_pointer"))
        #expect(names.contains("swl_data_device_manager_create_data_source"))
        #expect(names.contains("swl_primary_selection_device_manager_get_device"))
        #expect(!names.contains("swl_wl_compositor_create_surface"))
        #expect(!names.contains("swl_wl_data_device_manager_create_data_source"))
        #expect(
            policy.interfaces["wp_linux_drm_syncobj_manager_v1"]?
                .handwrittenRequests["import_timeline"] == .failureInjection
        )
        #expect(
            policy.interfaces["xdg_surface"]?
                .handwrittenRequests["set_window_geometry"] == .notExposed
        )
    }

    @Test
    func rendererMapsRequestArgumentsAndTypedNewIDs() {
        let policy = RequestBridgeInterfacePolicy(
            generatedRequests: ["create", "destroy"],
            wrapperPrefix: "example_device"
        )
        let createBridge = ResolvedRequestBridge(
            interface: fixtureInterface,
            request: fixtureInterface.requests[0],
            interfacePolicy: policy,
            generatedHeaderInclude: "generated/example/example-client-protocol.h"
        )
        let destroyBridge = ResolvedRequestBridge(
            interface: fixtureInterface,
            request: fixtureInterface.requests[1],
            interfacePolicy: policy,
            generatedHeaderInclude: "generated/example/example-client-protocol.h"
        )
        let header = RequestBridgeHeaderRenderer.render(
            bridges: [createBridge, destroyBridge]
        )
        let source = RequestBridgeSourceRenderer.render(
            bridges: [createBridge, destroyBridge]
        )

        #expect(header.contains("struct example_child_v1 *swl_example_device_create("))
        #expect(header.contains("int32_t request_signed_value"))
        #expect(header.contains("uint32_t request_unsigned_value"))
        #expect(header.contains("wl_fixed_t request_coordinate"))
        #expect(header.contains("const char *request_title"))
        #expect(header.contains("struct example_peer_v1 *request_peer"))
        #expect(header.contains("struct wl_array *request_bytes"))
        #expect(header.contains("int32_t request_descriptor"))
        #expect(header.contains("void swl_example_device_destroy("))
        #expect(!header.contains("request_child"))
        #expect(source.contains("return example_device_v1_create("))
        #expect(source.contains("#include \"generated/example/example-client-protocol.h\""))
    }

    @Test
    func policyRejectsAnUnclassifiedRequest() {
        let policy = RequestBridgePolicy(
            interfaces: [
                "example_device_v1": RequestBridgeInterfacePolicy(
                    generatedRequests: ["create"]
                )
            ]
        )

        #expect(throws: ToolError.self) {
            try policy.validate(against: [fixtureProtocol])
        }
    }

    @Test
    func policyRejectsAnUntypedNewID() {
        let request = WaylandMessageIR(
            name: "create",
            opcode: 0,
            since: 1,
            deprecatedSince: nil,
            isDestructor: false,
            arguments: [argument("child", type: .newID)]
        )
        let interface = WaylandInterfaceIR(
            name: "example_device_v1",
            version: 1,
            requests: [request],
            events: [],
            enumerations: []
        )
        let policy = RequestBridgePolicy(
            interfaces: [
                interface.name: RequestBridgeInterfacePolicy(
                    generatedRequests: [request.name]
                )
            ]
        )

        #expect(throws: ToolError.self) {
            try policy.validate(
                against: [WaylandProtocolIR(name: "example", interfaces: [interface])]
            )
        }
    }

    private var fixtureProtocol: WaylandProtocolIR {
        WaylandProtocolIR(name: "example", interfaces: [fixtureInterface])
    }

    private var fixtureInterface: WaylandInterfaceIR {
        WaylandInterfaceIR(
            name: "example_device_v1",
            version: 1,
            requests: [
                WaylandMessageIR(
                    name: "create",
                    opcode: 0,
                    since: 1,
                    deprecatedSince: nil,
                    isDestructor: false,
                    arguments: [
                        argument(
                            "child",
                            type: .newID,
                            interfaceName: "example_child_v1"
                        ),
                        argument("signed_value", type: .int),
                        argument("unsigned_value", type: .uint),
                        argument("coordinate", type: .fixed),
                        argument("title", type: .string),
                        argument(
                            "peer",
                            type: .object,
                            interfaceName: "example_peer_v1"
                        ),
                        argument("bytes", type: .array),
                        argument("descriptor", type: .fileDescriptor),
                    ]
                ),
                WaylandMessageIR(
                    name: "destroy",
                    opcode: 1,
                    since: 1,
                    deprecatedSince: nil,
                    isDestructor: true,
                    arguments: []
                ),
            ],
            events: [],
            enumerations: []
        )
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
