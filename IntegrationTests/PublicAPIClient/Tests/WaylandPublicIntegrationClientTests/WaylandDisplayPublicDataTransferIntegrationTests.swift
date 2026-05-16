import Testing
import WaylandClient

extension WaylandDisplayPublicIntegrationTests {
    @Test
    func clipboardOfferForUnknownSeatReportsPublicError() async throws {
        try await withPublicConnection { display in
            let capabilities = try await display.capabilities()
            let unknownSeatID = SeatID(rawValue: UInt32.max)

            do {
                _ = try await display.clipboardOffer(for: unknownSeatID)
                Issue.record("Expected a clipboard public error")
            } catch let error as DataTransferError {
                switch error {
                case .unavailable:
                    #expect(capabilities.clipboard == .unavailable)
                    noteOptionalProtocolSkip(
                        test: "clipboard",
                        interfaceName: "wl_data_device_manager"
                    )
                case .unknownSeat(let seatID), .missingDataDevice(let seatID):
                    #expect(capabilities.clipboard.isAvailable)
                    #expect(seatID == unknownSeatID)
                default:
                    Issue.record("Expected clipboard error, got \(error)")
                }
            } catch {
                Issue.record("Expected DataTransferError, got \(error)")
            }
        }
    }
}
