import Testing
import WaylandClient

extension WaylandDisplayPublicIntegrationTests {
    @Test
    func textInputSessionForUnknownSeatReportsPublicError() async throws {
        try await withPublicConnection { display in
            let capabilities = try await display.capabilities()
            let unknownSeatID = SeatID(rawValue: UInt32.max)

            do {
                _ = try await display.textInputSession(for: unknownSeatID)
                Issue.record("Expected a text-input public error")
            } catch let error as TextInputError {
                switch error {
                case .unavailable:
                    #expect(capabilities.textInput == .unavailable)
                    noteOptionalProtocolSkip(
                        test: "text-input",
                        interfaceName: "zwp_text_input_manager_v3"
                    )
                case .unknownSeat(let seatID):
                    #expect(capabilities.textInput.isAvailable)
                    #expect(seatID == unknownSeatID)
                default:
                    Issue.record("Expected text-input availability error, got \(error)")
                }
            } catch {
                Issue.record("Expected TextInputError, got \(error)")
            }
        }
    }
}
