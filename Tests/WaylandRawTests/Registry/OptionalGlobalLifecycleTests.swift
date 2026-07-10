import Testing

@testable import WaylandRaw

@Suite
struct OptionalGlobalLifecycleTests {
    @Test
    func removalDestroysBoundGlobalExactlyOnce() {
        let object = DestroyCounter()
        var global: OptionalGlobal = .bound(object)

        retireOptionalGlobal(&global)
        retireOptionalGlobal(&global)

        #expect(object.destroyCount == 1)
        #expect(!global.isBound)
    }

    @Test
    func removalClearsUnsupportedVersionState() {
        var global: OptionalVersionedGlobal<DestroyCounter> = .unsupportedVersion(
            advertised: 1,
            minimum: 2
        )

        retireOptionalGlobal(&global)

        guard case .missing = global else {
            Issue.record("expected removed global to become missing")
            return
        }
    }
}

private final class DestroyCounter: RawDestroyableObject {
    private(set) var destroyCount = 0

    func destroy() {
        destroyCount += 1
    }
}
