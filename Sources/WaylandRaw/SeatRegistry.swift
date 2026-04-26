import CWaylandProtocols

package final class SeatRegistry {
    private let registry: OpaquePointer
    private let eventSink: RawInputEventSink
    private let operations: RawSeatProxyOperations
    private var seatsByGlobalName: [UInt32: RawSeat] = [:]
    private var unsupportedSeatVersionsByGlobalName: [UInt32: RawVersion] = [:]
    private var isDestroyed = false

    package init(
        registry rawRegistry: OpaquePointer,
        eventSink inputEventSink: RawInputEventSink,
        operations seatOperations: RawSeatProxyOperations = .live
    ) {
        registry = rawRegistry
        eventSink = inputEventSink
        operations = seatOperations
    }

    package var seats: [RawSeat] {
        seatsByGlobalName
            .sorted { $0.key < $1.key }
            .map(\.value)
    }

    package var unsupportedSeatVersions: [UInt32: RawVersion] {
        unsupportedSeatVersionsByGlobalName
    }

    package func seat(for id: RawSeatID) -> RawSeat? {
        seatsByGlobalName[id.rawValue]
    }

    package func bindSeats(from globals: [RawGlobalAdvertisement]) throws {
        for global in globals where global.interfaceName == "wl_seat" {
            try bindSeat(globalName: global.name, advertisedVersion: global.advertisedVersion)
        }
    }

    @discardableResult
    package func bindSeat(globalName: UInt32, advertisedVersion: RawVersion) throws -> RawSeat? {
        if let existing = seatsByGlobalName[globalName] {
            return existing
        }

        guard advertisedVersion >= 5 else {
            unsupportedSeatVersionsByGlobalName[globalName] = advertisedVersion
            return nil
        }

        unsupportedSeatVersionsByGlobalName[globalName] = nil
        let negotiated = min(advertisedVersion, SupportedVersions.wlSeat)
        guard let seatPointer = operations.bindSeat(registry, globalName, negotiated.value) else {
            throw RuntimeError.bindFailed("wl_seat")
        }

        do {
            let seat = try RawSeat(
                id: RawSeatID(rawValue: globalName),
                pointer: seatPointer,
                version: negotiated,
                eventSink: eventSink,
                operations: operations
            )
            seatsByGlobalName[globalName] = seat
            return seat
        } catch {
            operations.releaseSeat(seatPointer)
            throw error
        }
    }

    package func removeSeat(globalName: UInt32) {
        guard let seat = seatsByGlobalName.removeValue(forKey: globalName) else {
            return
        }

        seat.handleRemovedGlobal()
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        let seats =
            seatsByGlobalName
            .sorted { $0.key < $1.key }
            .map(\.value)
        seatsByGlobalName.removeAll()

        for seat in seats {
            seat.destroy()
        }
    }

    deinit {
        destroy()
    }
}
