import Foundation
import Testing
import WaylandClient

private let primarySelectionTimeoutMS: Int32 = 5_000

@Suite(
    "Primary selection public integration",
    .enabled(
        if: PrimarySelectionPublicEnvironment.isEnabled,
        "Set WAYLAND_DISPLAY and SWIFT_WAYLAND_ENABLE_PUBLIC_INTEGRATION_TESTS=1"
    ),
    .serialized
)
struct PrimarySelectionPublicIntegrationTests {
    @Test
    func primarySelectionOfferForUnknownSeatReportsPublicError() async throws {
        try await withPrimarySelectionPublicConnection { display in
            let unknownSeatID = SeatID(rawValue: UInt32.max)

            do {
                _ = try await display.primarySelectionOffer(for: unknownSeatID)
                Issue.record("Expected a primary-selection public error")
            } catch let error as DataTransferError {
                switch error {
                case .unavailable:
                    break
                case .missingPrimarySelectionDevice(let seatID):
                    #expect(seatID == unknownSeatID)
                default:
                    Issue.record("Expected primary-selection error, got \(error)")
                }
            } catch {
                Issue.record("Expected DataTransferError, got \(error)")
            }
        }
    }
}

private func withPrimarySelectionPublicConnection(
    _ body: @Sendable (WaylandDisplay) async throws -> Void
) async throws {
    try await WaylandDisplay.withConnection(
        cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
        discoveryTimeoutMilliseconds: primarySelectionTimeoutMS,
        eventStreamConfiguration: try EventStreamConfiguration(
            displayEventCapacity: 64,
            inputEventCapacity: 64,
            dataTransferEventCapacity: 64
        ),
        body
    )
}

private enum PrimarySelectionPublicEnvironment {
    static var isEnabled: Bool {
        environmentValue("SWIFT_WAYLAND_ENABLE_PUBLIC_INTEGRATION_TESTS") == "1"
            && environmentValue("WAYLAND_DISPLAY") != nil
    }

    static func environmentValue(_ key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key],
            !value.isEmpty
        else {
            return nil
        }

        return value
    }
}
