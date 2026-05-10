import Testing
import WaylandClient

extension WaylandDisplayPublicIntegrationTests {
    @Test
    func xdgOutputLogicalGeometryIsPublishedWhenAdvertised() async throws {
        try await withPublicConnection { display in
            let capabilities = try await display.capabilities()
            guard capabilities.xdgOutput.isAvailable else {
                noteOptionalProtocolSkip(
                    test: "xdg-output logical geometry",
                    interfaceName: "zxdg_output_manager_v1"
                )
                return
            }

            let outputs = try await withTimeout(
                nanoseconds: publicIntegrationWaitTimeoutNanoseconds,
                operation: "waiting for xdg-output logical geometry"
            ) {
                while true {
                    let outputs = try await display.outputs()
                    if outputs.contains(where: { $0.logicalGeometry != nil }) {
                        return outputs
                    }

                    try await Task.sleep(nanoseconds: 10_000_000)
                }
            }

            #expect(outputs.contains { $0.logicalGeometry != nil })
        }
    }

    @Test
    func toplevelWindowPublishesOutputMembershipThroughPublicAPI() async throws {
        try await withPublicConnection { display in
            let displayEvents = display.events
            let window = try await display.createTopLevelWindow(
                configuration: testWindowConfiguration()
            )

            let event = try await displayEvent(
                in: displayEvents,
                matching: { event in
                    guard case .windowOutputsChanged(let membership) = event else {
                        return false
                    }

                    return membership.windowID == window.id && !membership.outputs.isEmpty
                },
                after: {
                    try await show(window, color: 0x0018_2838)
                }
            )

            guard case .windowOutputsChanged(let membership) = event else {
                Issue.record("Expected window output membership event, got \(event)")
                await window.close()
                return
            }

            let windowSnapshot = try await window.stateSnapshot
            let displayOutputs = try await display.outputs()
            let displayOutputIDs = Set(displayOutputs.map(\.id))

            #expect(membership.windowID == window.id)
            #expect(windowSnapshot.outputs == membership.outputs)
            #expect(!membership.outputs.isEmpty)
            #expect(Set(membership.outputs).isSubset(of: displayOutputIDs))

            await window.close()
        }
    }
}
