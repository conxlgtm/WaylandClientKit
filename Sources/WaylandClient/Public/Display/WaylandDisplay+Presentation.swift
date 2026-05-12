extension WaylandDisplay {
    package nonisolated func windowPresentationEvents(
        for windowID: WindowID
    ) -> WindowPresentationEvents {
        runtime.windowPresentationEvents(for: windowID)
    }
}
