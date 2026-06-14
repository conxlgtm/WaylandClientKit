enum WaylandDisplayLifecycle {
    case initializing
    case active(core: DisplayCore, eventSource: DisplayEventSource)
    case primarySelectionTestHarness(any WaylandDisplayPrimarySelectionHandling)
    case closed
    case abandoned

    var isInitializing: Bool {
        switch self {
        case .initializing:
            true
        case .active, .primarySelectionTestHarness, .closed, .abandoned:
            false
        }
    }
}
