import CWaylandProtocols

@safe
package final class SeatRegistry {
    @safe private let registry: OpaquePointer
    private let eventSink: RawInputEventSink
    private let proxyAdoption: RawProxyAdoptionContext?
    private let invariantFailureSink: RawInvariantFailureSink?
    private let operations: RawSeatProxyOperations
    private var seatsByGlobalName: [UInt32: RawSeat] = [:]
    private var unsupportedSeatVersionsByGlobalName: [UInt32: RawVersion] = [:]
    private var isDestroyed = false

    package init(
        registry rawRegistry: OpaquePointer,
        eventSink inputEventSink: RawInputEventSink,
        proxyAdoption adoptionContext: RawProxyAdoptionContext? = nil,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        operations seatOperations: RawSeatProxyOperations = .live
    ) {
        unsafe registry = rawRegistry
        eventSink = inputEventSink
        proxyAdoption = adoptionContext
        invariantFailureSink = failureSink
        operations = seatOperations
    }

    package var seats: [RawSeat] {
        seatsByGlobalName.valuesSortedByKey()
    }

    package var unsupportedSeatVersions: [UInt32: RawVersion] {
        unsupportedSeatVersionsByGlobalName
    }

    package func seat(for id: RawSeatID) -> RawSeat? {
        seatsByGlobalName[id.rawValue]
    }

    package func setPointerCursor(
        seatID: RawSeatID,
        serial: UInt32,
        surfacePointer: OpaquePointer?,
        hotspotX: Int32,
        hotspotY: Int32,
    ) -> RawPointerCursorResult {
        guard let seat = seat(for: seatID) else { return .skippedUnknownSeat(seatID) }

        return unsafe seat.setPointerCursor(
            serial: serial,
            surfacePointer: surfacePointer,
            hotspotX: hotspotX,
            hotspotY: hotspotY
        )
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
        guard
            let seatPointer = unsafe operations.bindSeat(
                registry, globalName, negotiated.value)
        else {
            throw RuntimeError.bindFailed("wl_seat")
        }

        let seat = try unsafe RawSeat(
            id: RawSeatID(rawValue: globalName),
            pointer: seatPointer,
            version: negotiated,
            eventSink: eventSink,
            proxyAdoption: proxyAdoption,
            invariantFailureSink: invariantFailureSink,
            operations: operations
        )
        seatsByGlobalName[globalName] = seat
        return seat
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
        let seats = seatsByGlobalName.valuesSortedByKey()
        seatsByGlobalName.removeAll()

        for seat in seats {
            seat.destroy()
        }
    }

    deinit {
        destroy()
    }
}
