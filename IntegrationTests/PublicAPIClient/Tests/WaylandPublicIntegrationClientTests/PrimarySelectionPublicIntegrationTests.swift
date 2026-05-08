import Foundation
import Testing
import WaylandClient

private let primarySelectionTimeoutMS: Int32 = 5_000
private let primarySelectionWaitNS: UInt64 = 5_000_000_000

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

@Suite(
    "Primary selection public behavior",
    .enabled(
        if: PrimarySelectionPublicEnvironment.isEnabled
            && PrimarySelectionPublicFixture.isEnabled,
        "Set primary-selection public integration environment variables"
    ),
    .serialized
)
struct PrimarySelectionPublicBehaviorTests {
    @Test
    func requestPrimarySelectionPublishesPrimarySelectionEvent() async throws {
        let fixture = try #require(PrimarySelectionPublicFixture.current)

        try await withPrimarySelectionPublicConnection { display in
            guard
                try await primarySelectionCapabilityIsAvailable(
                    display,
                    seatID: fixture.seatID
                )
            else {
                return
            }

            let dataTransferEvents = display.dataTransferEvents
            let configuration = try primarySelectionSourceConfiguration()

            let event = try await dataTransferEvent(
                in: dataTransferEvents,
                matching: { event in
                    isPrimarySelectionChangedEvent(
                        event,
                        seatID: fixture.seatID,
                        offer: nil
                    )
                },
                after: {
                    try await requestPrimarySelection(
                        display,
                        configuration: configuration,
                        fixture: fixture
                    )
                }
            )

            #expect(isPrimarySelectionChangedEvent(event, seatID: fixture.seatID, offer: nil))
        }
    }

    @Test
    func clearingPrimarySelectionSourcePublishesSourceCancellation() async throws {
        let fixture = try #require(PrimarySelectionPublicFixture.current)

        try await withPrimarySelectionPublicConnection { display in
            guard
                try await primarySelectionCapabilityIsAvailable(
                    display,
                    seatID: fixture.seatID
                )
            else {
                return
            }

            let dataTransferEvents = display.dataTransferEvents
            let configuration = try primarySelectionSourceConfiguration()
            let source = try await display.requestPrimarySelection(
                configuration,
                seatID: fixture.seatID,
                serial: fixture.serial
            )

            let event = try await dataTransferEvent(
                in: dataTransferEvents,
                matching: { event in
                    isPrimarySelectionSourceCancelledEvent(event, source: source.identity)
                },
                after: {
                    try await source.requestClear(serial: fixture.serial)
                }
            )

            #expect(isPrimarySelectionSourceCancelledEvent(event, source: source.identity))
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

private func primarySelectionSourceConfiguration() throws -> PrimarySelectionSourceConfiguration {
    try PrimarySelectionSourceConfiguration.data(
        mimeType: .plainText,
        Data("primary".utf8)
    )
}

private func requestPrimarySelection(
    _ display: WaylandDisplay,
    configuration: PrimarySelectionSourceConfiguration,
    fixture: PrimarySelectionPublicFixture
) async throws {
    let source = try await display.requestPrimarySelection(
        configuration,
        seatID: fixture.seatID,
        serial: fixture.serial
    )

    #expect(source.seatID == fixture.seatID)
    #expect(source.mimeTypes == [.plainText])
}

private func dataTransferEvent(
    in events: DataTransferEvents,
    matching predicate: @escaping @Sendable (DataTransferEvent) -> Bool,
    after trigger: @escaping @Sendable () async throws -> Void
) async throws -> DataTransferEvent {
    try await withPrimarySelectionTimeout {
        try await withThrowingTaskGroup(of: DataTransferEvent.self) { group in
            group.addTask {
                try await nextDataTransferEvent(in: events, matching: predicate)
            }

            await Task.yield()
            try await trigger()

            guard let event = try await group.next() else {
                throw PrimarySelectionPublicIntegrationError.streamEnded
            }
            group.cancelAll()
            return event
        }
    }
}

private func nextDataTransferEvent(
    in events: DataTransferEvents,
    matching predicate: @escaping @Sendable (DataTransferEvent) -> Bool
) async throws -> DataTransferEvent {
    var iterator = events.makeAsyncIterator()
    while let event = try await iterator.next() {
        if predicate(event) {
            return event
        }
    }

    throw PrimarySelectionPublicIntegrationError.streamEnded
}

private func isPrimarySelectionChangedEvent(
    _ event: DataTransferEvent,
    seatID expectedSeatID: SeatID,
    offer expectedOffer: PrimarySelectionOfferIdentity?
) -> Bool {
    guard case .primarySelectionChanged(let event) = event else {
        return false
    }

    return event.seatID == expectedSeatID && event.offer == expectedOffer
}

private func isPrimarySelectionSourceCancelledEvent(
    _ event: DataTransferEvent,
    source expectedSource: PrimarySelectionSourceIdentity
) -> Bool {
    guard case .primarySelectionSourceCancelled(let source) = event else {
        return false
    }

    return source == expectedSource
}

private func primarySelectionCapabilityIsAvailable(
    _ display: WaylandDisplay,
    seatID: SeatID
) async throws -> Bool {
    do {
        _ = try await display.primarySelectionOffer(for: seatID)
        return true
    } catch let error as DataTransferError {
        switch error {
        case .unavailable:
            return false
        default:
            throw error
        }
    }
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

private struct PrimarySelectionPublicFixture: Sendable {
    let seatID: SeatID
    let serial: InputSerial

    static var isEnabled: Bool {
        current != nil
    }

    static var current: PrimarySelectionPublicFixture? {
        guard let seatRawValue = environmentUInt32("SWIFT_WAYLAND_PRIMARY_SELECTION_SEAT_ID"),
            let serialRawValue = environmentUInt32("SWIFT_WAYLAND_PRIMARY_SELECTION_SERIAL")
        else {
            return nil
        }

        return PrimarySelectionPublicFixture(
            seatID: SeatID(rawValue: seatRawValue),
            serial: InputSerial(rawValue: serialRawValue)
        )
    }

    private static func environmentUInt32(_ key: String) -> UInt32? {
        guard let value = PrimarySelectionPublicEnvironment.environmentValue(key) else {
            return nil
        }

        return UInt32(value)
    }
}

private enum PrimarySelectionPublicIntegrationError: Error {
    case timeout
    case streamEnded
}

private func withPrimarySelectionTimeout<Value: Sendable>(
    _ body: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask {
            try await body()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: primarySelectionWaitNS)
            throw PrimarySelectionPublicIntegrationError.timeout
        }

        guard let value = try await group.next() else {
            throw PrimarySelectionPublicIntegrationError.timeout
        }

        group.cancelAll()
        return value
    }
}
