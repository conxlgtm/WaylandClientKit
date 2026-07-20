import WaylandRuntime

/// Owns the thread and event streams that have to outlive an active display core.
@safe
final class DisplayLifetimeAnchor: Sendable {
    let executor: WaylandThreadExecutor
    let eventHub: DisplayEventHub

    init(configuration: DisplayConfiguration) throws {
        eventHub = DisplayEventHub(
            configuration: configuration.eventStreams,
            diagnosticsConfiguration: configuration.diagnostics
        )
        executor = try WaylandThreadExecutor()
    }

    deinit {
        executor.shutdown()
    }

    func displayDidDeinitialize(lifecycle: inout WaylandDisplayLifecycle) {
        switch lifecycle {
        case .closed, .abandoned:
            executor.requestStopAfterCurrentJob()
            return
        case .initializing, .primarySelectionTestHarness:
            eventHub.finish(throwing: .closed)
            lifecycle = .closed
            executor.requestStopAfterCurrentJob()
            return
        case .active(let leakedCore, _):
            #if DEBUG
                assertionFailure("WaylandDisplay leaked; call close() or use withConnection(_:)")
            #endif

            eventHub.finish(throwing: .closed)
            executor.abandonWaylandEventSourceWithoutDestroyingRawResources()

            // A missed close can deinitialize from an arbitrary thread. Normal
            // Wayland teardown is ordered owner-thread work, so release builds
            // abandon the raw graph instead of faking cleanup from deinit.
            unsafe intentionallyLeakObjectForWrongThreadResourceFallback(leakedCore)
            lifecycle = .abandoned
            executor.requestStopAfterCurrentJob(.abandonWaylandSources)
        }
    }
}
