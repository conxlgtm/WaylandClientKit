extension WaylandDisplay {
    package nonisolated func managedSurfacePresentationEvents(
        for surface: ManagedSurfaceIdentity
    ) -> ManagedSurfacePresentationEvents {
        lifetimeAnchor.eventHub.managedSurfacePresentationEvents(surface: surface)
    }
}
