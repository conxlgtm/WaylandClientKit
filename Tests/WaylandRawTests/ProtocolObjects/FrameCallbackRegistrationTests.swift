import CWaylandProtocols
import Testing

@testable import WaylandRaw

@Suite
struct FrameCallbackRegistrationTests {
    @Test
    func consumingCancelAndDeinitDestroyOnce() throws {
        let counters = CallbackCounters()
        let pointer = try makeCallbackPointer(0x100)
        do {
            let registration = try FrameCallbackRegistration(
                pointer: pointer,
                onDone: {
                    // The cancellation path should not invoke this closure.
                },
                operations: counters.operations(addResult: 0)
            )
            registration.cancel()
        }
        #expect(counters.addCount == 1)
        #expect(counters.destroyCount == 1)
    }
    @Test
    func installFailureDestroysProxyBeforeThrowing() throws {
        let counters = CallbackCounters()
        let pointer = try makeCallbackPointer(0x200)
        var didThrow = false
        do {
            _ = try FrameCallbackRegistration(
                pointer: pointer,
                onDone: {
                    // The failed install path should not invoke this closure.
                },
                operations: counters.operations(addResult: -1)
            )
        } catch {
            didThrow = true
        }
        #expect(didThrow)
        #expect(counters.addCount == 1)
        #expect(counters.destroyCount == 1)
    }
    @Test
    func doneFiresClosureAtMostOnceAndDestroysLocalClientProxy() throws {
        let counters = CallbackCounters()
        let pointer = try makeCallbackPointer(0x300)
        var fireCount = 0
        let state = WaylandCallbackRegistrationState(
            pointer: pointer,
            onDone: {
                fireCount += 1
            },
            operations: counters.operations(addResult: 0)
        )
        try state.install()
        state.handleDone()
        state.cancel()
        #expect(fireCount == 1)
        #expect(state.lifecycle == .completed(.fired))
        #expect(counters.localProxyDestroyCount == 1)
        #expect(counters.wireDestroyRequestCount == 0)
    }
    @Test
    func doneKeepsListenerStateAliveThroughHandler() throws {
        let counters = CallbackCounters()
        let pointer = try makeCallbackPointer(0x350)
        let box = CallbackRegistrationBox()
        var didFire = false
        box.registration = try FrameCallbackRegistration(
            pointer: pointer,
            onDone: {
                didFire = true
                box.registration = nil
            },
            operations: counters.operations(addResult: 0)
        )
        let callbacks = try counters.installedCallbacks()
        unsafe callbacks.pointee.done?(callbacks.pointee.data, pointer, 0)
        #expect(didFire)
        #expect(!box.hasRegistration)
        #expect(counters.localProxyDestroyCount == 1)
        #expect(counters.wireDestroyRequestCount == 0)
    }
    @Test
    func doneInvalidatesListenerStorageWhileKeepingCallbackPayloadAlive() throws {
        let counters = CallbackCounters()
        let pointer = try makeCallbackPointer(0x375)
        var state: WaylandCallbackRegistrationState?
        var storageWasInvalidatedDuringHandler = false
        var storageWasAliveDuringHandler = false
        let callbackState = WaylandCallbackRegistrationState(
            pointer: pointer,
            onDone: {
                guard let state else { return }
                storageWasInvalidatedDuringHandler = !state.listenerStorageIsValidForTesting
                storageWasAliveDuringHandler = state.listenerStorageCallbackActive
            },
            operations: counters.operations(addResult: 0)
        )
        state = callbackState
        try callbackState.install()
        let callbacks = try counters.installedCallbacks()
        unsafe callbacks.pointee.done?(callbacks.pointee.data, pointer, 0)
        #expect(storageWasInvalidatedDuringHandler)
        #expect(storageWasAliveDuringHandler)
        #expect(callbackState.lifecycle == .completed(.fired))
        #expect(counters.localProxyDestroyCount == 1)
    }
    @Test
    func cancelIsIdempotentOnState() throws {
        let counters = CallbackCounters()
        let pointer = try makeCallbackPointer(0x400)
        let state = WaylandCallbackRegistrationState(
            pointer: pointer,
            onDone: {
                // Cancellation is being tested, not callback delivery.
            },
            operations: counters.operations(addResult: 0)
        )
        try state.install()
        state.cancel()
        state.cancel()
        #expect(state.lifecycle == .completed(.cancelled))
        #expect(counters.localProxyDestroyCount == 1)
    }
}
@safe
private func makeCallbackPointer(_ rawValue: Int) throws -> OpaquePointer {
    try unsafe #require(OpaquePointer(bitPattern: rawValue))
}
private final class CallbackRegistrationBox {
    var registration: FrameCallbackRegistration?
    var hasRegistration: Bool {
        registration != nil
    }
}
@safe
private final class CallbackCounters {
    private(set) var addCount = 0
    private(set) var localProxyDestroyCount = 0
    private(set) var wireDestroyRequestCount = 0
    @safe private(set) var callbacks: UnsafePointer<swl_callback_listener_callbacks>?

    var destroyCount: Int {
        localProxyDestroyCount
    }

    @safe
    func operations(addResult: Int32) -> WaylandCallbackOperations {
        let counters = self
        return unsafe WaylandCallbackOperations(
            addListener: { _, callbacks in
                counters.recordAdd()
                unsafe counters.callbacks = callbacks
                return addResult
            },
            destroy: { _ in
                counters.recordDestroy()
            }
        )
    }
    private func recordAdd() {
        addCount += 1
    }
    private func recordDestroy() {
        localProxyDestroyCount += 1
    }
    @safe
    func installedCallbacks() throws -> UnsafePointer<swl_callback_listener_callbacks> {
        try unsafe #require(callbacks)
    }
}
