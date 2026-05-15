import Testing

@testable import WaylandRaw

@Suite
struct OptionalGlobalTests {
    @Test
    func optionalGlobalDestroyRunsOnlyWhenBound() {
        let recorder = DestroyableRecorder()
        let bound = OptionalGlobal.bound(recorder)
        let missing = OptionalGlobal<DestroyableRecorder>.missing

        missing.destroy()
        bound.destroy()

        #expect(recorder.destroyCount == 1)
        #expect(bound.boundObject === recorder)
        #expect(missing.boundObject == nil)
        #expect(bound.isBound)
        #expect(!missing.isBound)
    }

    @Test
    func optionalVersionedGlobalPreservesUnsupportedVersionState() {
        let unsupported = OptionalVersionedGlobal<DestroyableRecorder>
            .unsupportedVersion(advertised: RawVersion(1), minimum: RawVersion(2))

        switch unsupported {
        case .unsupportedVersion(let advertised, let minimum):
            #expect(advertised == RawVersion(1))
            #expect(minimum == RawVersion(2))
        case .missing,
            .bound:
            Issue.record("expected unsupported version state")
        }

        #expect(unsupported.boundObject == nil)
        #expect(!unsupported.isBound)
    }

    private final class DestroyableRecorder: RawDestroyableObject {
        private(set) var destroyCount = 0

        func destroy() {
            destroyCount += 1
        }
    }
}
