package protocol FractionalScaleAcquisitionFactory {
    associatedtype Viewport
    associatedtype FractionalScale
    associatedtype FractionalScaleOwner
    associatedtype Resources

    func createViewport() throws -> Viewport
    func createFractionalScale() throws -> FractionalScale
    func createOwner() -> FractionalScaleOwner
    func installOwner(_ owner: FractionalScaleOwner, on scale: FractionalScale) throws
    func destroyViewport(_ viewport: Viewport)
    func destroyFractionalScale(_ scale: FractionalScale)
    func cancelOwner(_ owner: FractionalScaleOwner)
    func makeResources(
        viewport: Viewport,
        fractionalScale: FractionalScale,
        owner: FractionalScaleOwner
    ) -> Resources
}

package enum ScaleInstallationAcquisition {
    package static func install<SurfaceScaleOwner, Installation>(
        surfaceScaleOwner: SurfaceScaleOwner,
        makeInstallation: (SurfaceScaleOwner) throws -> Installation,
        cancelSurfaceScaleOwner: (SurfaceScaleOwner) -> Void
    ) rethrows -> Installation {
        do {
            return try makeInstallation(surfaceScaleOwner)
        } catch {
            cancelSurfaceScaleOwner(surfaceScaleOwner)
            throw error
        }
    }

    package static func acquireFractionalResources<
        Factory: FractionalScaleAcquisitionFactory
    >(
        using factory: Factory
    ) throws -> Factory.Resources {
        let viewport = try factory.createViewport()

        do {
            let fractionalScale = try factory.createFractionalScale()
            let owner = factory.createOwner()

            do {
                try factory.installOwner(owner, on: fractionalScale)
                return factory.makeResources(
                    viewport: viewport,
                    fractionalScale: fractionalScale,
                    owner: owner
                )
            } catch {
                factory.cancelOwner(owner)
                factory.destroyFractionalScale(fractionalScale)
                throw error
            }
        } catch {
            factory.destroyViewport(viewport)
            throw error
        }
    }
}
