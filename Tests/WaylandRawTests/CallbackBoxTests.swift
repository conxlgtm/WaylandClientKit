import Testing

@testable import WaylandRaw

@Suite
struct CallbackBoxTests {
    final class Owner {}
    final class ListenerOwner {
        lazy var storage = CallbackBoxStorage(owner: self)
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
