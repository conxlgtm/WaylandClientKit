import CWaylandProtocols
import Testing

@testable import WaylandRaw

@Suite
struct FrameCallbackRegistrationTests {
    @Test
    func consumingCancelAndDeinitDestroyOnce() throws {
        let counters = CallbackCounters()
        let pointer = try #require(OpaquePointer(bitPattern: 0x100))

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
        let pointer = try #require(OpaquePointer(bitPattern: 0x200))
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
        let pointer = try #require(OpaquePointer(bitPattern: 0x300))
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
        #expect(state.lifecycle == .fired)
        #expect(counters.localProxyDestroyCount == 1)
        #expect(counters.wireDestroyRequestCount == 0)
    }

    @Test
    func doneKeepsListenerStateAliveThroughHandler() throws {
        let counters = CallbackCounters()
        let pointer = try #require(OpaquePointer(bitPattern: 0x350))
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

        let callbacks = try #require(counters.callbacks)
        callbacks.pointee.done?(callbacks.pointee.data, pointer, 0)

        #expect(didFire)
        #expect(!box.hasRegistration)
        #expect(counters.localProxyDestroyCount == 1)
        #expect(counters.wireDestroyRequestCount == 0)
    }

    @Test
    func cancelIsIdempotentOnState() throws {
        let counters = CallbackCounters()
        let pointer = try #require(OpaquePointer(bitPattern: 0x400))
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

        #expect(state.lifecycle == .cancelled)
        #expect(counters.localProxyDestroyCount == 1)
    }
}

private final class CallbackRegistrationBox {
    var registration: FrameCallbackRegistration?

    var hasRegistration: Bool {
        registration != nil
    }
}

private final class CallbackCounters {
    private(set) var addCount = 0
    private(set) var localProxyDestroyCount = 0
    private(set) var wireDestroyRequestCount = 0
    private(set) var callbacks: UnsafePointer<swl_callback_listener_callbacks>?

    var destroyCount: Int {
        localProxyDestroyCount
    }

    func operations(addResult: Int32) -> WaylandCallbackOperations {
        let counters = self

        return WaylandCallbackOperations(
            addListener: { _, callbacks in
                counters.recordAdd()
                counters.callbacks = callbacks
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
}
