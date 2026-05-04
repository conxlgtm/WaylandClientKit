import Testing

@testable import WaylandClient

@Suite
struct ScaleInstallationAcquisitionTests {
    @Test
    func scaleInstallationReturnsFractionalResourcesOnSuccess() throws {
        let factory = FakeFractionalScaleFactory()

        let resources = try ScaleInstallationAcquisition.acquireFractionalResources(
            using: factory
        )

        #expect(resources.viewport === factory.viewport)
        #expect(resources.fractionalScale === factory.fractionalScale)
        #expect(resources.owner === factory.owner)
        #expect(factory.viewport.destroyCount == 0)
        #expect(factory.fractionalScale.destroyCount == 0)
        #expect(factory.owner.cancelCount == 0)
        #expect(factory.ownerCreateCount == 1)
    }

    @Test
    func scaleInstallationDoesNotCancelSurfaceScaleOwnerOnSuccess() {
        let surfaceScaleOwner = FakeSurfaceScaleOwner()

        let installation: FakeScaleInstallation =
            ScaleInstallationAcquisition.install(
                surfaceScaleOwner: surfaceScaleOwner,
                makeInstallation: { _ in
                    FakeScaleInstallation()
                },
                cancelSurfaceScaleOwner: { owner in
                    owner.cancel()
                }
            )

        #expect(installation == FakeScaleInstallation())
        #expect(surfaceScaleOwner.cancelCount == 0)
    }

    @Test
    func scaleInstallationDestroysViewportWhenFractionalScaleCreationFails() {
        let factory = FakeFractionalScaleFactory(
            failure: .fractionalScaleCreationFailed
        )

        #expect(throws: FakeScaleInstallationError.fractionalScaleCreationFailed) {
            let _: FakeFractionalResources =
                try ScaleInstallationAcquisition.acquireFractionalResources(using: factory)
        }

        #expect(factory.viewport.destroyCount == 1)
        #expect(factory.ownerCreateCount == 0)
    }

    @Test
    func scaleInstallationDestroysViewportAndFractionalScaleWhenListenerInstallFails() {
        let factory = FakeFractionalScaleFactory(
            failure: .listenerInstallFailed
        )

        #expect(throws: FakeScaleInstallationError.listenerInstallFailed) {
            let _: FakeFractionalResources =
                try ScaleInstallationAcquisition.acquireFractionalResources(using: factory)
        }

        #expect(factory.owner.cancelCount == 1)
        #expect(factory.fractionalScale.destroyCount == 1)
        #expect(factory.viewport.destroyCount == 1)
    }

    @Test
    func scaleInstallationCancelsSurfaceScaleOwnerWhenFractionalSetupFails() {
        let surfaceScaleOwner = FakeSurfaceScaleOwner()

        #expect(throws: FakeScaleInstallationError.fractionalScaleCreationFailed) {
            let _: FakeScaleInstallation =
                try ScaleInstallationAcquisition.install(
                    surfaceScaleOwner: surfaceScaleOwner,
                    makeInstallation: { _ in
                        throw FakeScaleInstallationError.fractionalScaleCreationFailed
                    },
                    cancelSurfaceScaleOwner: { owner in
                        owner.cancel()
                    }
                )
        }

        #expect(surfaceScaleOwner.cancelCount == 1)
    }
}

private enum FakeScaleInstallationError: Error, Equatable {
    case fractionalScaleCreationFailed
    case listenerInstallFailed
}

private final class FakeFractionalScaleFactory: FractionalScaleAcquisitionFactory {
    let viewport = FakeViewport()
    let fractionalScale = FakeFractionalScale()
    let owner = FakeFractionalScaleOwner()
    private let selectedFailure: FakeScaleInstallationError?
    private(set) var ownerCreateCount = 0

    init(failure: FakeScaleInstallationError? = nil) {
        selectedFailure = failure
    }

    func createViewport() throws -> FakeViewport {
        viewport
    }

    func createFractionalScale() throws -> FakeFractionalScale {
        if let selectedFailure, selectedFailure == .fractionalScaleCreationFailed {
            throw selectedFailure
        }

        return fractionalScale
    }

    func createOwner() -> FakeFractionalScaleOwner {
        ownerCreateCount += 1
        return owner
    }

    func installOwner(
        _: FakeFractionalScaleOwner,
        on _: FakeFractionalScale
    ) throws {
        if let selectedFailure, selectedFailure == .listenerInstallFailed {
            throw selectedFailure
        }
    }

    func destroyViewport(_ viewport: FakeViewport) {
        viewport.destroy()
    }

    func destroyFractionalScale(_ scale: FakeFractionalScale) {
        scale.destroy()
    }

    func cancelOwner(_ owner: FakeFractionalScaleOwner) {
        owner.cancel()
    }

    func makeResources(
        viewport: FakeViewport,
        fractionalScale: FakeFractionalScale,
        owner: FakeFractionalScaleOwner
    ) -> FakeFractionalResources {
        FakeFractionalResources(
            viewport: viewport,
            fractionalScale: fractionalScale,
            owner: owner
        )
    }
}

private final class FakeSurfaceScaleOwner {
    private(set) var cancelCount = 0

    func cancel() {
        cancelCount += 1
    }
}

private final class FakeViewport {
    private(set) var destroyCount = 0

    func destroy() {
        destroyCount += 1
    }
}

private final class FakeFractionalScale {
    private(set) var destroyCount = 0

    func destroy() {
        destroyCount += 1
    }
}

private final class FakeFractionalScaleOwner {
    private(set) var cancelCount = 0

    func cancel() {
        cancelCount += 1
    }
}

private struct FakeFractionalResources {
    let viewport: FakeViewport
    let fractionalScale: FakeFractionalScale
    let owner: FakeFractionalScaleOwner
}

private struct FakeScaleInstallation: Equatable {}
