import Foundation
import Testing
import WaylandClient

@Suite("WaylandDisplay public API surface")
struct WaylandDisplayPublicAPISurfaceTests {
    @Test
    func primarySelectionPublicTypesCompileForExternalClients() throws {
        let payload = DataTransferSourcePayload(
            mimeType: .plainText,
            data: Data("primary".utf8)
        )
        let configuration = try PrimarySelectionSourceConfiguration(payloads: [payload])

        #expect(configuration.payloads == [payload])
        #expect(
            try PrimarySelectionSourceConfiguration.data(
                mimeType: .plainTextUTF8,
                Data("primary utf8".utf8)
            ).payloads.first?.mimeType == .plainTextUTF8)
    }

    @Test
    func primarySelectionDisplayMethodsCompileForExternalClients() {
        func usePrimarySelectionAPI(
            display: WaylandDisplay,
            seatID: SeatID,
            serial: InputSerial
        ) async throws {
            let configuration = try PrimarySelectionSourceConfiguration.data(
                mimeType: .plainText,
                Data("primary".utf8)
            )
            let source = try await display.requestPrimarySelection(
                configuration,
                seatID: seatID,
                serial: serial
            )
            _ = try await display.primarySelectionOffer(for: seatID)
            try await source.requestClear(serial: serial)
            try await display.requestClearPrimarySelection(seatID: seatID, serial: serial)
        }

        _ = usePrimarySelectionAPI
    }

    @Test
    func capabilityTypesAndDisplayMethodCompileForExternalClients() {
        let availability = ProtocolAvailability.available(version: 1)
        let capabilities = WaylandCapabilities(
            clipboard: availability,
            primarySelection: .unavailable,
            xdgDecoration: .available(version: 2),
            viewporter: .available(version: 1),
            fractionalScale: .unavailable
        )

        #expect(availability.isAvailable)
        #expect(availability.version == 1)
        #expect(capabilities.clipboard == .available(version: 1))
        #expect(capabilities.primarySelection == .unavailable)

        func useCapabilitiesAPI(display: WaylandDisplay) async throws -> WaylandCapabilities {
            try await display.capabilities()
        }

        _ = useCapabilitiesAPI
    }

    @Test
    func primarySelectionDataTransferEventsCompileForExternalClients() {
        func consumeDataTransferEvent(_ event: DataTransferEvent) -> String {
            switch event {
            case .clipboardSelectionChanged(let event):
                event.offer?.description ?? "clipboard cleared"
            case .primarySelectionChanged(let event):
                event.offer?.description ?? "primary selection cleared"
            case .clipboardSourceCancelled(let identity):
                identity.description
            case .primarySelectionSourceCancelled(let identity):
                identity.description
            }
        }

        _ = consumeDataTransferEvent
    }
}
