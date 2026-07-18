import Foundation
import Testing

@testable import WaylandClientKitToolSupport

@Suite
struct RegistryBindBridgeGenerationTests {
    @Test
    func checkedInRegistryBindBridgesMatchStableRendererOutput() throws {
        let tooling = ProtocolTooling(repository: Repository(root: repositoryRoot))
        let first = try tooling.renderRegistryBindBridgeArtifacts()
        let second = try tooling.renderRegistryBindBridgeArtifacts()
        let checkedInHeader = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                RegistryBindBridgeGeneration.headerOutputPath
            ),
            encoding: .utf8
        )
        let checkedInSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                RegistryBindBridgeGeneration.sourceOutputPath
            ),
            encoding: .utf8
        )

        #expect(first == second)
        #expect(first.header == checkedInHeader)
        #expect(first.source == checkedInSource)
    }

    @Test
    func generationPolicyOwnsRegistryInventoryVersionsAndOptionality() throws {
        let tooling = ProtocolTooling(repository: Repository(root: repositoryRoot))
        let policy = try tooling.loadGenerationPolicy()
        let bridges = try RegistryBindBridgeGeneration.resolve(
            protocols: tooling.loadProtocolIRs(),
            manifest: tooling.loadManifest(),
            policy: policy
        )
        let requiredInterfaces = bridges.compactMap { bridge in
            bridge.policy.globalBinding == .required ? bridge.interface.name : nil
        }

        #expect(bridges.count == 39)
        #expect(Set(requiredInterfaces) == Set(["wl_compositor", "wl_shm", "xdg_wm_base"]))
        #expect(bridges.allSatisfy { $0.functionName == "swl_registry_bind_\($0.interface.name)" })
        #expect(policy.interfaces["wl_seat"]?.maximumSupportedVersion == 10)
        #expect(policy.interfaces["wl_seat"]?.minimumRequiredVersion == 5)
        #expect(policy.interfaces["wl_seat"]?.globalBinding == .optional)
        #expect(policy.interfaces["zxdg_decoration_manager_v1"]?.minimumRequiredVersion == 1)
        #expect(policy.interfaces["zxdg_output_manager_v1"]?.minimumRequiredVersion == 2)
        #expect(policy.interfaces["xdg_wm_base"]?.maximumSupportedVersion == 7)
    }

    @Test
    func rendererPassesTheNegotiatedVersionStraightToRegistryBind() {
        let bridge = ResolvedRegistryBindBridge(
            interface: WaylandInterfaceIR(
                name: "example_manager_v1",
                version: 3,
                requests: [],
                events: [],
                enumerations: []
            ),
            policy: WaylandInterfaceGenerationPolicy(
                maximumSupportedVersion: 2,
                globalBinding: .optional
            ),
            generatedHeaderInclude: "generated/example/example-v1-client-protocol.h"
        )
        let header = RegistryBindBridgeHeaderRenderer.render(bridges: [bridge])
        let source = RegistryBindBridgeSourceRenderer.render(bridges: [bridge])

        #expect(
            header.contains(
                "struct example_manager_v1 *swl_registry_bind_example_manager_v1("
            )
        )
        #expect(
            source.contains(
                "registry, name, &example_manager_v1_interface, version);"
            )
        )
        #expect(
            source.contains(
                "#include \"generated/example/example-v1-client-protocol.h\""
            )
        )
        #expect(!source.contains("wl_proxy_set_queue"))
        #expect(!source.contains("wl_proxy_destroy"))
        #expect(!source.contains("maximumSupportedVersion"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
