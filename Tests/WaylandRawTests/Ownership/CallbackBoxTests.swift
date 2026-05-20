import Testing

@testable import WaylandRaw

@Suite
struct CallbackBoxTests {
    final class Owner {}
    final class ListenerOwner {
        lazy var storage = CallbackBoxStorage(owner: self)
    }

    final class ReleasingListenerOwner {
        var storage: CListenerStorage<ReleasingListenerOwner, ListenerCallbacks>?
    }

    final class FailureRecorder: RawInvariantFailureReporter {
        var failures: [RawInvariantFailure] = []

        func reportFatalRawInvariantFailure(_ failure: RawInvariantFailure) {
            failures.append(failure)
        }
    }

    struct ListenerCallbacks {
        var value = 0
    }

    final class WeakListenerStorage {
        weak var storage: CListenerStorage<ReleasingListenerOwner, ListenerCallbacks>?

        init(_ listenerStorage: CListenerStorage<ReleasingListenerOwner, ListenerCallbacks>?) {
            storage = listenerStorage
        }
    }

    @Test
    func callbackBoxRoundTripsThroughOpaquePointer() {
        let owner = ListenerOwner()
        let opaque = owner.storage.opaquePointer
        let recovered = CallbackBox<ListenerOwner>.fromOpaque(opaque)
        let isSameOwner =
            recovered.withOwner { recoveredOwner in
                recoveredOwner === owner
            } ?? false
        #expect(recovered === owner.storage.box)
        #expect(isSameOwner)
        #expect(recovered.isValid)
    }
    @Test
    func callbackBoxStorageInvalidationClearsOwner() {
        let owner = ListenerOwner()
        owner.storage.invalidate()
        #expect(owner.storage.owner == nil)
        #expect(owner.storage.isValid == false)
        #expect(owner.storage.box.withOwner { _ in true } == nil)
    }
    @Test
    func cListenerStorageRoundTripsThroughOpaquePointer() {
        let owner = ReleasingListenerOwner()
        let storage = CListenerStorage(
            owner: owner,
            initialValue: ListenerCallbacks()
        )
        owner.storage = storage
        var didRecoverOwner = false
        CListenerStorage<ReleasingListenerOwner, ListenerCallbacks>.withOwner(
            from: storage.opaqueOwnerPointer,
            message: "test listener storage missing owner"
        ) { recoveredOwner in
            didRecoverOwner = recoveredOwner === owner
            recoveredOwner.storage?.callbacks.pointee.value = 42
        }
        #expect(didRecoverOwner)
        #expect(storage.callbacks.pointee.value == 42)
        #expect(storage.isValidForTesting)
        #expect(!storage.hasActiveCallbacksForTesting)
    }
    @Test
    func cListenerStorageInvalidationClearsOwner() {
        let owner = ReleasingListenerOwner()
        let storage = CListenerStorage(
            owner: owner,
            initialValue: ListenerCallbacks()
        )
        owner.storage = storage
        storage.invalidate()
        #expect(!storage.isValidForTesting)
        #expect(!storage.hasActiveCallbacksForTesting)
    }
    @Test
    func cListenerStorageStaysAliveThroughReentrantRelease() {
        let owner = ReleasingListenerOwner()
        var storage: CListenerStorage<ReleasingListenerOwner, ListenerCallbacks>? =
            CListenerStorage(owner: owner, initialValue: ListenerCallbacks())
        let weakStorage = WeakListenerStorage(storage)
        owner.storage = storage
        let opaque = storage?.opaqueOwnerPointer
        storage = nil
        CListenerStorage<ReleasingListenerOwner, ListenerCallbacks>.withOwner(
            from: opaque,
            message: "test listener storage missing owner"
        ) { recoveredOwner in
            #expect(weakStorage.storage?.hasActiveCallbacksForTesting == true)
            recoveredOwner.storage = nil
            #expect(weakStorage.storage != nil)
        }
        #expect(weakStorage.storage == nil)
    }
    #if DEBUG
        @Test
        func cListenerStorageForwardsFatalInvariantFailures() {
            let recorder = FailureRecorder()
            let sink = RawInvariantFailureSink()
            sink.reporter = recorder
            let owner = ReleasingListenerOwner()
            let storage = CListenerStorage(
                owner: owner,
                initialValue: ListenerCallbacks(),
                invariantFailureSink: sink
            )
            let failure = RawInvariantFailure.callbackWithoutSwiftState(
                "test listener storage missing owner"
            )
            storage.reportFatalInvariantFailureForTesting(failure)
            #expect(recorder.failures == [failure])
        }
    #endif
    @Test
    func callbackBoxInvalidationClearsOwner() {
        let owner = Owner()
        let box = CallbackBox(owner)
        box.invalidate()
        #expect(box.owner == nil)
        #expect(box.isValid == false)
        #expect(box.withOwner { _ in true } == nil)
    }
    @Test
    func callbackBoxLosesOwnerWhenOwnerDeallocates() {
        let box: CallbackBox<Owner>
        do {
            let owner = Owner()
            box = CallbackBox(owner)
            #expect(box.owner != nil)
            #expect(box.isValid)
        }
        #expect(box.owner == nil)
        #expect(box.isValid == false)
        #expect(box.withOwner { _ in true } == nil)
    }
}
