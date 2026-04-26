import Testing

@testable import WaylandRaw

@Suite
struct RawSeatLifecycleTests {
    @Test
    func capabilityChangesCreateAndReleaseChildProxies() throws {
        let recorder = SeatOperationRecorder()
        recorder.pointerProxy = fakePointer(0x201)
        recorder.keyboardProxy = fakePointer(0x202)
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 4),
            pointer: try #require(fakePointer(0x200)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        try seat.applyCapabilities([.pointer, .keyboard])

        #expect(seat.advertisedCapabilities == [.pointer, .keyboard])
        #expect(seat.activeCapabilities == [.pointer, .keyboard])
        #expect(
            recorder.entries == [
                "get pointer",
                "version",
                "get keyboard",
                "version",
            ])

        let createdSnapshot = try #require(queue.drain().last)
        #expect(
            createdSnapshot.kind
                == .seat(
                    RawSeatEventSnapshot(
                        advertisedCapabilities: [.pointer, .keyboard],
                        activeCapabilities: [.pointer, .keyboard],
                        name: nil
                    )
                ))

        try seat.applyCapabilities([.keyboard])

        #expect(seat.advertisedCapabilities == [.keyboard])
        #expect(seat.activeCapabilities == [.keyboard])
        #expect(Array(recorder.entries.suffix(1)) == ["release pointer"])

        seat.destroy()

        #expect(
            Array(recorder.entries.suffix(2)) == [
                "release keyboard",
                "release seat",
            ])
    }

    @Test
    func childCreationFailureKeepsAdvertisedStateAndCreatesOtherChildren() throws {
        let recorder = SeatOperationRecorder()
        recorder.pointerProxy = nil
        recorder.keyboardProxy = fakePointer(0x302)
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 5),
            pointer: try #require(fakePointer(0x300)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        do {
            try seat.applyCapabilities([.pointer, .keyboard])
            Issue.record("Expected pointer creation to fail")
        } catch RuntimeError.bindFailed(let interfaceName) {
            #expect(interfaceName == "wl_pointer")
        }

        #expect(seat.advertisedCapabilities == [.pointer, .keyboard])
        #expect(seat.activeCapabilities == [.keyboard])
        #expect(
            recorder.entries == [
                "get pointer",
                "get keyboard",
                "version",
            ])

        let snapshot = try #require(queue.drain().last)
        #expect(
            snapshot.kind
                == .seat(
                    RawSeatEventSnapshot(
                        advertisedCapabilities: [.pointer, .keyboard],
                        activeCapabilities: [.keyboard],
                        name: nil
                    )
                ))
    }

    @Test
    func globalRemovalDestroysChildrenBeforeSeatAndEmitsRemoval() throws {
        let recorder = SeatOperationRecorder()
        recorder.pointerProxy = fakePointer(0x401)
        recorder.keyboardProxy = fakePointer(0x402)
        recorder.touchProxy = fakePointer(0x403)
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 6),
            pointer: try #require(fakePointer(0x400)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        try seat.applyCapabilities([.pointer, .keyboard, .touch])
        _ = queue.drain()
        recorder.entries.removeAll()

        seat.handleRemovedGlobal()

        #expect(
            recorder.entries == [
                "release touch",
                "release keyboard",
                "release pointer",
                "release seat",
            ])
        #expect(seat.advertisedCapabilities.isEmpty)
        #expect(seat.activeCapabilities.isEmpty)
        #expect(queue.drain().map(\.kind) == [.seatRemoved])
    }

    @Test
    func nameEventsUpdateSeatSnapshot() throws {
        let recorder = SeatOperationRecorder()
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 7),
            pointer: try #require(fakePointer(0x500)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        seat.applyName("default")

        #expect(seat.name == "default")
        #expect(
            queue.drain().last?.kind
                == .seat(
                    RawSeatEventSnapshot(
                        advertisedCapabilities: [],
                        activeCapabilities: [],
                        name: "default"
                    )
                ))
    }
}

@Suite
struct SeatRegistryTests {
    @Test
    func registryBindsSupportedSeatsAndSkipsOldVersions() throws {
        let recorder = SeatOperationRecorder()
        let queue = RawInputEventQueue()
        let registry = SeatRegistry(
            registry: try #require(fakePointer(0x600)),
            eventSink: queue,
            operations: recorder.operations
        )

        try registry.bindSeats(from: [
            RawGlobalAdvertisement(name: 2, interfaceName: "wl_seat", advertisedVersion: 4),
            RawGlobalAdvertisement(name: 3, interfaceName: "wl_seat", advertisedVersion: 10),
        ])

        #expect(registry.seats.map(\.id) == [RawSeatID(rawValue: 3)])
        #expect(
            recorder.entries == [
                "bind seat 3 v10",
                "add seat listener",
            ])
    }

    @Test
    func removingBoundSeatIsIdempotent() throws {
        let recorder = SeatOperationRecorder()
        let queue = RawInputEventQueue()
        let registry = SeatRegistry(
            registry: try #require(fakePointer(0x700)),
            eventSink: queue,
            operations: recorder.operations
        )

        try registry.bindSeat(globalName: 9, advertisedVersion: 10)
        recorder.entries.removeAll()

        registry.removeSeat(globalName: 9)
        registry.removeSeat(globalName: 9)

        #expect(registry.seats.isEmpty)
        #expect(recorder.entries == ["release seat"])
        #expect(queue.drain().map(\.kind) == [.seatRemoved])
    }
}

private final class SeatOperationRecorder {
    var entries: [String] = []
    var pointerProxy: OpaquePointer?
    var keyboardProxy: OpaquePointer?
    var touchProxy: OpaquePointer?

    var operations: RawSeatProxyOperations {
        RawSeatProxyOperations(
            bindSeat: { [self] _, name, version in
                entries.append("bind seat \(name) v\(version)")
                return OpaquePointer(bitPattern: Int(0x1_000 + name))
            },
            addSeatListener: { [self] _, _ in
                entries.append("add seat listener")
                return 0
            },
            getPointer: { [self] _ in
                entries.append("get pointer")
                return pointerProxy
            },
            getKeyboard: { [self] _ in
                entries.append("get keyboard")
                return keyboardProxy
            },
            getTouch: { [self] _ in
                entries.append("get touch")
                return touchProxy
            },
            proxyVersion: { [self] _ in
                entries.append("version")
                return 10
            },
            releasePointer: { [self] _ in
                entries.append("release pointer")
            },
            releaseKeyboard: { [self] _ in
                entries.append("release keyboard")
            },
            releaseTouch: { [self] _ in
                entries.append("release touch")
            },
            releaseSeat: { [self] _ in
                entries.append("release seat")
            }
        )
    }
}

private func fakePointer(_ bitPattern: Int) -> OpaquePointer? {
    OpaquePointer(bitPattern: bitPattern)
}
