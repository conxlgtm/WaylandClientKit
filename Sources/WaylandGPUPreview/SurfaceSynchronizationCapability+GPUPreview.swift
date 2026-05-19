import WaylandClient

extension SurfaceSynchronizationCapability {
    package var supportsExplicit: Bool {
        switch self {
        case .implicitOnly:
            false
        case .explicitAvailable, .explicitActive:
            true
        }
    }
}
