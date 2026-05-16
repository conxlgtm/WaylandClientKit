import Testing
import WaylandClient

extension WaylandDisplayPublicIntegrationTests {
    @Test
    func primarySelectionOfferForUnknownSeatReportsPublicError() async throws {
        try await withPublicConnection { display in
            let capabilities = try await display.capabilities()
            let unknownSeatID = SeatID(rawValue: UInt32.max)

            do {
                _ = try await display.primarySelectionOffer(for: unknownSeatID)
                Issue.record("Expected a primary-selection public error")
            } catch let error as DataTransferError {
                switch error {
                case .unavailable:
                    #expect(capabilities.primarySelection == .unavailable)
                    noteOptionalProtocolSkip(
                        test: "primary selection",
                        interfaceName: "zwp_primary_selection_device_manager_v1"
                    )
                case .missingPrimarySelectionDevice(let seatID):
                    #expect(capabilities.primarySelection.isAvailable)
                    #expect(seatID == unknownSeatID)
                default:
                    Issue.record("Expected primary-selection error, got \(error)")
                }
            } catch {
                Issue.record("Expected DataTransferError, got \(error)")
            }
        }
    }

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

    @Test
    func dragOfferForUnknownSeatReportsPublicError() async throws {
        try await withPublicConnection { display in
            let capabilities = try await display.capabilities()
            let unknownSeatID = SeatID(rawValue: UInt32.max)

            do {
                _ = try await display.dragOffer(for: unknownSeatID)
                Issue.record("Expected a drag-and-drop public error")
            } catch let error as DataTransferError {
                switch error {
                case .unavailable:
                    #expect(capabilities.dragAndDrop == .unavailable)
                    noteOptionalProtocolSkip(
                        test: "drag-and-drop",
                        interfaceName: "wl_data_device_manager"
                    )
                case .unknownSeat(let seatID), .missingDataDevice(let seatID):
                    #expect(capabilities.dragAndDrop.isAvailable)
                    #expect(seatID == unknownSeatID)
                default:
                    Issue.record("Expected drag-and-drop error, got \(error)")
                }
            } catch {
                Issue.record("Expected DataTransferError, got \(error)")
            }
        }
    }
}
