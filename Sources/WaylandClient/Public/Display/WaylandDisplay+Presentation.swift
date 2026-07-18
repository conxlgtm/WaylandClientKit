extension WaylandDisplay {
    package nonisolated func windowPresentationEvents(
        for windowID: WindowID
    ) -> WindowPresentationEvents {
        lifetimeAnchor.eventHub.windowPresentationEvents(windowID: windowID)
    }
}
