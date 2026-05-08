// swiftlint:disable file_length
import CWaylandProtocols
import Glibc
import Testing

@testable import WaylandRaw

@Suite
struct RawSeatLifecycleTests {  // swiftlint:disable:this type_body_length
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
                "add pointer listener",
                "version",
                "get keyboard",
                "add keyboard listener",
                "version",
            ])

        let createdSnapshot = try #require(queue.drain().last)
        #expect(
            createdSnapshot.kind
                == .seat(
                    RawSeatEventSnapshot(
                        uncheckedAdvertisedCapabilities: [.pointer, .keyboard],
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
                "add keyboard listener",
                "version",
            ])

        let snapshot = try #require(queue.drain().last)
        #expect(
            snapshot.kind
                == .seat(
                    RawSeatEventSnapshot(
                        uncheckedAdvertisedCapabilities: [.pointer, .keyboard],
                        activeCapabilities: [.keyboard],
                        name: nil
                    )
                ))
    }

    @Test
    func destroyAfterChildCreationFailureReleasesOnlyCreatedChildren() throws {
        let recorder = SeatOperationRecorder()
        recorder.pointerProxy = nil
        recorder.keyboardProxy = fakePointer(0x312)
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 15),
            pointer: try #require(fakePointer(0x310)),
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
        seat.destroy()

        #expect(
            recorder.entries == [
                "get pointer",
                "get keyboard",
                "add keyboard listener",
                "version",
                "release keyboard",
                "release seat",
            ]
        )
    }

    @Test
    func pointerCreateFailureEmitsSeatBindingDiagnostic() throws {
        let recorder = SeatOperationRecorder()
        recorder.pointerProxy = nil
        let queue = RawInputEventQueue()
        let seatID = RawSeatID(rawValue: 19)
        let deviceID = RawInputDeviceID(seatID: seatID, kind: .pointer, generation: 1)
        let seat = try RawSeat(
            id: seatID,
            pointer: try #require(fakePointer(0x320)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        #expect(throws: RuntimeError.bindFailed("wl_pointer")) {
            try seat.applyCapabilities([.pointer])
        }

        let events = queue.drain()
        #expect(events.first?.deviceID == deviceID)
        #expect(
            events.map(\.kind)
                == [
                    .diagnostic(
                        RawInputDiagnostic(
                            .seatBinding(
                                RawSeatBindingDiagnostic(
                                    interface: "wl_pointer",
                                    error: .bindFailed("wl_pointer")
                                )
                            )
                        )
                    ),
                    .seat(
                        RawSeatEventSnapshot(
                            uncheckedAdvertisedCapabilities: [.pointer],
                            activeCapabilities: [],
                            name: nil
                        )
                    ),
                ]
        )
        #expect(queue.drain().isEmpty)
        #expect(seat.activeCapabilities.isEmpty)
    }

    @Test
    func pointerListenerInstallFailureEmitsSeatBindingDiagnostic() throws {
        let recorder = SeatOperationRecorder()
        recorder.pointerProxy = fakePointer(0x331)
        recorder.pointerListenerResult = -1
        let queue = RawInputEventQueue()
        let seatID = RawSeatID(rawValue: 20)
        let seat = try RawSeat(
            id: seatID,
            pointer: try #require(fakePointer(0x330)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        #expect(throws: RuntimeError.pointerListenerInstallationFailed) {
            try seat.applyCapabilities([.pointer])
        }

        #expect(
            recorder.entries == [
                "get pointer",
                "add pointer listener",
                "release pointer",
            ]
        )
        #expect(
            queue.drain().map(\.kind)
                == [
                    .diagnostic(
                        RawInputDiagnostic(
                            .seatBinding(
                                RawSeatBindingDiagnostic(
                                    interface: "wl_pointer",
                                    error: .pointerListenerInstallationFailed
                                )
                            )
                        )
                    ),
                    .seat(
                        RawSeatEventSnapshot(
                            uncheckedAdvertisedCapabilities: [.pointer],
                            activeCapabilities: [],
                            name: nil
                        )
                    ),
                ]
        )
        #expect(seat.activeCapabilities.isEmpty)
    }

    @Test
    func keyboardListenerInstallFailureEmitsSeatBindingDiagnostic() throws {
        let recorder = SeatOperationRecorder()
        recorder.keyboardProxy = fakePointer(0x341)
        recorder.keyboardListenerResult = -1
        let queue = RawInputEventQueue()
        let seatID = RawSeatID(rawValue: 21)
        let seat = try RawSeat(
            id: seatID,
            pointer: try #require(fakePointer(0x340)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        #expect(throws: RuntimeError.keyboardListenerInstallationFailed) {
            try seat.applyCapabilities([.keyboard])
        }

        #expect(
            recorder.entries == [
                "get keyboard",
                "add keyboard listener",
                "release keyboard",
            ]
        )
        #expect(
            queue.drain().map(\.kind)
                == [
                    .diagnostic(
                        RawInputDiagnostic(
                            .seatBinding(
                                RawSeatBindingDiagnostic(
                                    interface: "wl_keyboard",
                                    error: .keyboardListenerInstallationFailed
                                )
                            )
                        )
                    ),
                    .seat(
                        RawSeatEventSnapshot(
                            uncheckedAdvertisedCapabilities: [.keyboard],
                            activeCapabilities: [],
                            name: nil
                        )
                    ),
                ]
        )
        #expect(seat.activeCapabilities.isEmpty)
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
                        uncheckedAdvertisedCapabilities: [],
                        activeCapabilities: [],
                        name: "default"
                    )
                ))
    }

    @Test
    func emptyNameEventClearsSeatName() throws {
        let recorder = SeatOperationRecorder()
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 17),
            pointer: try #require(fakePointer(0x501)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        seat.applyName("default")
        seat.applyName("")

        #expect(seat.name == nil)
        #expect(queue.drain().last?.kind == .seat(seat.snapshot))
    }

    @Test
    func nullNameCallbackRecordsRawInvariantFailure() throws {
        let operationRecorder = SeatOperationRecorder()
        let failureRecorder = RawInvariantFailureRecorder()
        let sink = RawInvariantFailureSink()
        sink.reporter = failureRecorder
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 18),
            pointer: try #require(fakePointer(0x502)),
            version: 10,
            eventSink: queue,
            invariantFailureSink: sink,
            operations: operationRecorder.operations
        )
        let callbacks = try #require(operationRecorder.seatCallbacks)

        callbacks.pointee.name?(callbacks.pointee.data, seat.pointer, nil)

        #expect(failureRecorder.failures == [.missingSeatName])
        #expect(queue.drain().isEmpty)
    }

    @Test
    func pointerCallbacksEmitInputEvents() throws {
        let recorder = SeatOperationRecorder()
        recorder.pointerProxy = fakePointer(0x801)
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 8),
            pointer: try #require(fakePointer(0x800)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        try seat.applyCapabilities([.pointer])
        _ = queue.drain()

        let callbacks = try #require(recorder.pointerCallbacks)
        callbacks.pointee.motion?(
            callbacks.pointee.data,
            recorder.pointerProxy,
            123,
            256,
            512
        )

        let event = try #require(queue.drain().last)
        #expect(event.seatID == RawSeatID(rawValue: 8))
        #expect(event.deviceID?.kind == .pointer)
        #expect(
            event.kind
                == .pointer(
                    .motion(
                        RawPointerMotion(
                            time: 123,
                            x: WaylandFixed(rawValue: 256),
                            y: WaylandFixed(rawValue: 512)
                        )
                    )
                ))
    }

    @Test
    func setPointerCursorUsesCurrentPointerChild() throws {
        let recorder = SeatOperationRecorder()
        recorder.pointerProxy = fakePointer(0x8A1)
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 14),
            pointer: try #require(fakePointer(0x8A0)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        try seat.applyCapabilities([.pointer])
        _ = queue.drain()
        recorder.entries.removeAll()

        let result = seat.setPointerCursor(
            serial: 77,
            surfacePointer: fakePointer(0x900),
            hotspotX: 3,
            hotspotY: 4
        )

        #expect(
            recorder.entries.suffix(1) == [
                "set cursor serial=77 surface=0x900 hotspot=3,4"
            ])
        #expect(
            result
                == .set(
                    RawPointerCursorSetResult(
                        seatID: RawSeatID(rawValue: 14),
                        serial: 77,
                        surfaceID: 0x900,
                        hotspotX: 3,
                        hotspotY: 4
                    )
                ))
    }

    @Test
    func keyboardCallbacksCopyEnterKeys() throws {
        let recorder = SeatOperationRecorder()
        recorder.keyboardProxy = fakePointer(0x901)
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 9),
            pointer: try #require(fakePointer(0x900)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        try seat.applyCapabilities([.keyboard])
        _ = queue.drain()

        let callbacks = try #require(recorder.keyboardCallbacks)
        var pressedKeys = [UInt32(30), UInt32(31)]
        let keyArrayByteCount = pressedKeys.count * MemoryLayout<UInt32>.stride
        pressedKeys.withUnsafeMutableBufferPointer { keyBuffer in
            var keyArray = wl_array(
                size: keyArrayByteCount,
                alloc: keyArrayByteCount,
                data: UnsafeMutableRawPointer(keyBuffer.baseAddress)
            )
            callbacks.pointee.enter?(
                callbacks.pointee.data,
                recorder.keyboardProxy,
                44,
                fakePointer(0x777),
                &keyArray
            )
        }

        let enter = try #require(queue.drain().last)
        #expect(
            enter.kind
                == .keyboard(
                    .enter(
                        RawKeyboardEnter(
                            serial: 44,
                            surfaceID: 0x777,
                            pressedKeys: [30, 31]
                        )
                    )
                ))
    }

    @Test
    func keyboardKeymapCallbackCopiesBytes() throws {
        let recorder = SeatOperationRecorder()
        recorder.keyboardProxy = fakePointer(0x981)
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 11),
            pointer: try #require(fakePointer(0x980)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        try seat.applyCapabilities([.keyboard])
        _ = queue.drain()

        let callbacks = try #require(recorder.keyboardCallbacks)
        let bytes = [UInt8(1), UInt8(2), UInt8(3), UInt8(0)]
        let descriptor = try makeTemporaryFileDescriptor(bytes: bytes)

        callbacks.pointee.keymap?(
            callbacks.pointee.data,
            recorder.keyboardProxy,
            RawKeyboardKeymapFormat.xkbV1.rawValue,
            descriptor,
            UInt32(bytes.count)
        )

        let event = try #require(queue.drain().last)
        #expect(
            event.kind
                == .keyboard(
                    .keymap(
                        try RawKeyboardKeymapPayload.xkbV1(
                            id: RawKeyboardKeymapID(
                                seatID: RawSeatID(rawValue: 11),
                                keyboardGeneration: 1,
                                keymapGeneration: 1
                            ),
                            bytes: bytes
                        )
                    )
                ))
    }

    @Test
    func failedKeyboardKeymapCallbackConsumesGeneration() throws {
        let seatID = RawSeatID(rawValue: 12)
        let fixture = try makeKeyboardSeatFixture(
            seatID: seatID,
            seatPointer: 0x990,
            keyboardPointer: 0x991
        )

        let failedBytes = [UInt8(1), UInt8(2), UInt8(3)]
        try sendKeyboardKeymap(fixture, bytes: failedBytes)
        let failedEvent = try #require(fixture.queue.drain().last)
        #expect(
            failedEvent.kind
                == expectedMissingTerminatorKeymapFailure(
                    seatID: seatID,
                    keymapGeneration: 1,
                    byteCount: failedBytes.count
                ))

        let validBytes = [UInt8(4), UInt8(5), UInt8(0)]
        try sendKeyboardKeymap(fixture, bytes: validBytes)
        let successfulEvent = try #require(fixture.queue.drain().last)
        #expect(
            successfulEvent.kind
                == .keyboard(
                    .keymap(
                        try RawKeyboardKeymapPayload.xkbV1(
                            id: keyboardKeymapID(seatID: seatID, keymapGeneration: 2),
                            bytes: validBytes
                        )
                    )
                ))
    }

    @Test
    func consecutiveFailedKeyboardKeymapCallbacksUseDistinctIDs() throws {
        let seatID = RawSeatID(rawValue: 13)
        let fixture = try makeKeyboardSeatFixture(
            seatID: seatID,
            seatPointer: 0x9A0,
            keyboardPointer: 0x9A1
        )

        let firstBytes = [UInt8(1), UInt8(2)]
        try sendKeyboardKeymap(fixture, bytes: firstBytes)
        let firstEvent = try #require(fixture.queue.drain().last)
        #expect(
            firstEvent.kind
                == expectedMissingTerminatorKeymapFailure(
                    seatID: seatID,
                    keymapGeneration: 1,
                    byteCount: firstBytes.count
                ))

        let secondBytes = [UInt8(3), UInt8(4), UInt8(5)]
        try sendKeyboardKeymap(fixture, bytes: secondBytes)
        let secondEvent = try #require(fixture.queue.drain().last)
        #expect(
            secondEvent.kind
                == expectedMissingTerminatorKeymapFailure(
                    seatID: seatID,
                    keymapGeneration: 2,
                    byteCount: secondBytes.count
                ))
    }

    @Test
    func touchCallbacksEmitInputEvents() throws {
        let recorder = SeatOperationRecorder()
        recorder.touchProxy = fakePointer(0xA01)
        let queue = RawInputEventQueue()
        let seat = try RawSeat(
            id: RawSeatID(rawValue: 10),
            pointer: try #require(fakePointer(0xA00)),
            version: 10,
            eventSink: queue,
            operations: recorder.operations,
            installListener: false
        )

        try seat.applyCapabilities([.touch])
        _ = queue.drain()

        let callbacks = try #require(recorder.touchCallbacks)
        callbacks.pointee.down?(
            callbacks.pointee.data,
            recorder.touchProxy,
            1,
            2,
            fakePointer(0x333),
            3,
            256,
            512
        )

        let event = try #require(queue.drain().last)
        #expect(event.deviceID?.kind == .touch)
        #expect(
            event.kind
                == .touch(
                    .down(
                        RawTouchDown(
                            serial: 1,
                            time: 2,
                            surfaceID: 0x333,
                            id: 3,
                            x: WaylandFixed(rawValue: 256),
                            y: WaylandFixed(rawValue: 512)
                        )
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

        let oldSeat = try #require(
            RawGlobalAdvertisement(name: 2, interfaceName: "wl_seat", advertisedVersion: 4)
        )
        let currentSeat = try #require(
            RawGlobalAdvertisement(name: 3, interfaceName: "wl_seat", advertisedVersion: 10)
        )

        try registry.bindSeats(from: [oldSeat, currentSeat])

        #expect(registry.seats.map(\.id) == [RawSeatID(rawValue: 3)])
        #expect(registry.unsupportedSeatVersions == [2: RawVersion(4)])
        #expect(
            recorder.entries == [
                "bind seat 3 v10",
                "add seat listener",
            ])
    }

    @Test
    func bindSeatReleasesSeatOnceWhenConstructionFails() throws {
        let recorder = SeatOperationRecorder()
        recorder.seatListenerResult = -1
        let queue = RawInputEventQueue()
        let registry = SeatRegistry(
            registry: try #require(fakePointer(0x650)),
            eventSink: queue,
            operations: recorder.operations
        )

        #expect(throws: RuntimeError.seatListenerInstallationFailed) {
            try registry.bindSeat(globalName: 5, advertisedVersion: 10)
        }
        #expect(
            recorder.entries == [
                "bind seat 5 v10",
                "add seat listener",
                "release seat",
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
    var seatCallbacks: UnsafePointer<swl_seat_listener_callbacks>?
    var pointerCallbacks: UnsafePointer<swl_pointer_listener_callbacks>?
    var keyboardCallbacks: UnsafePointer<swl_keyboard_listener_callbacks>?
    var touchCallbacks: UnsafePointer<swl_touch_listener_callbacks>?
    var seatListenerResult: Int32 = 0
    var pointerListenerResult: Int32 = 0
    var keyboardListenerResult: Int32 = 0
    var touchListenerResult: Int32 = 0

    var operations: RawSeatProxyOperations {
        RawSeatProxyOperations(
            bindSeat: { [self] _, name, version in
                entries.append("bind seat \(name) v\(version)")
                return OpaquePointer(bitPattern: Int(0x1_000 + name))
            },
            addSeatListener: { [self] _, callbacks in
                entries.append("add seat listener")
                seatCallbacks = callbacks
                return seatListenerResult
            },
            addPointerListener: { [self] _, callbacks in
                entries.append("add pointer listener")
                pointerCallbacks = callbacks
                return pointerListenerResult
            },
            addKeyboardListener: { [self] _, callbacks in
                entries.append("add keyboard listener")
                keyboardCallbacks = callbacks
                return keyboardListenerResult
            },
            addTouchListener: { [self] _, callbacks in
                entries.append("add touch listener")
                touchCallbacks = callbacks
                return touchListenerResult
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
            setPointerCursor: { [self] _, serial, surface, hotspotX, hotspotY in
                entries.append(
                    "set cursor serial=\(serial) surface=\(hex(surface)) "
                        + "hotspot=\(hotspotX),\(hotspotY)"
                )
            },
            proxyVersion: { [self] _ in
                entries.append("version")
                return 10
            },
            proxyObjectID: { proxy in
                proxy.map { RawObjectID(UInt32(UInt(bitPattern: UnsafeRawPointer($0)))) }
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

private final class RawInvariantFailureRecorder: RawInvariantFailureReporter {
    var failures: [RawInvariantFailure] = []

    func reportFatalRawInvariantFailure(_ failure: RawInvariantFailure) {
        failures.append(failure)
    }
}

private struct KeyboardSeatFixture {
    let seat: RawSeat
    let queue: RawInputEventQueue
    let callbacks: UnsafePointer<swl_keyboard_listener_callbacks>
    let keyboardProxy: OpaquePointer?
}

private func makeKeyboardSeatFixture(
    seatID: RawSeatID,
    seatPointer: Int,
    keyboardPointer: Int
) throws -> KeyboardSeatFixture {
    let recorder = SeatOperationRecorder()
    recorder.keyboardProxy = fakePointer(keyboardPointer)
    let queue = RawInputEventQueue()
    let seat = try RawSeat(
        id: seatID,
        pointer: try #require(fakePointer(seatPointer)),
        version: 10,
        eventSink: queue,
        operations: recorder.operations,
        installListener: false
    )

    try seat.applyCapabilities([.keyboard])
    _ = queue.drain()

    return KeyboardSeatFixture(
        seat: seat,
        queue: queue,
        callbacks: try #require(recorder.keyboardCallbacks),
        keyboardProxy: recorder.keyboardProxy
    )
}

private func sendKeyboardKeymap(
    _ fixture: KeyboardSeatFixture,
    bytes: [UInt8],
    format: RawKeyboardKeymapFormat = .xkbV1
) throws {
    let descriptor = try makeTemporaryFileDescriptor(bytes: bytes)
    fixture.callbacks.pointee.keymap?(
        fixture.callbacks.pointee.data,
        fixture.keyboardProxy,
        format.rawValue,
        descriptor,
        UInt32(bytes.count)
    )
}

private func keyboardKeymapID(
    seatID: RawSeatID,
    keymapGeneration: UInt64
) -> RawKeyboardKeymapID {
    RawKeyboardKeymapID(
        seatID: seatID,
        keyboardGeneration: 1,
        keymapGeneration: keymapGeneration
    )
}

private func expectedMissingTerminatorKeymapFailure(
    seatID: RawSeatID,
    keymapGeneration: UInt64,
    byteCount: Int
) -> RawInputEventKind {
    .diagnostic(
        RawInputDiagnostic(
            .keymap(
                .readFailed(
                    id: keyboardKeymapID(
                        seatID: seatID,
                        keymapGeneration: keymapGeneration
                    ),
                    error: .missingNULTerminator(size: UInt32(byteCount))
                )
            )
        )
    )
}

private func fakePointer(_ bitPattern: Int) -> OpaquePointer? {
    OpaquePointer(bitPattern: bitPattern)
}

private func hex(_ pointer: OpaquePointer?) -> String {
    guard let pointer else { return "nil" }

    return "0x\(String(UInt(bitPattern: UnsafeRawPointer(pointer)), radix: 16))"
}

private func makeTemporaryFileDescriptor(bytes: [UInt8]) throws -> Int32 {
    var template = Array("/tmp/swift-wayland-seat-keymap-XXXXXX".utf8CString)
    let descriptor = template.withUnsafeMutableBufferPointer { buffer in
        guard let baseAddress = buffer.baseAddress else { return Int32(-1) }
        return mkstemp(baseAddress)
    }
    try #require(descriptor >= 0)
    template.withUnsafeBufferPointer { buffer in
        if let baseAddress = buffer.baseAddress {
            unlink(baseAddress)
        }
    }

    let writeResult = bytes.withUnsafeBytes { rawBytes in
        write(descriptor, rawBytes.baseAddress, bytes.count)
    }
    try #require(writeResult == bytes.count)
    try #require(lseek(descriptor, 0, SEEK_SET) == 0)
    return descriptor
}
