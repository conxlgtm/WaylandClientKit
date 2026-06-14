import WaylandRuntime

@safe
final class WaylandDisplayRuntime: Sendable {
    let executor: WaylandThreadExecutor
    let eventHub: DisplayEventHub

    init(configuration displayConfiguration: DisplayConfiguration) throws {
        eventHub = DisplayEventHub(
            configuration: displayConfiguration.eventStreams,
            diagnosticsConfiguration: displayConfiguration.diagnostics
        )
        executor = try WaylandThreadExecutor()
    }

    deinit {
        executor.shutdown()
    }

    var events: DisplayEvents {
        eventHub.displayEvents()
    }

    var inputEvents: InputEvents {
        eventHub.inputEvents()
    }

    var dataTransferEvents: DataTransferEvents {
        eventHub.dataTransferEvents()
    }

    func windowPresentationEvents(for windowID: WindowID) -> WindowPresentationEvents {
        eventHub.windowPresentationEvents(windowID: windowID)
    }

    var diagnostics: DisplayDiagnostics {
        eventHub.diagnostics()
    }

    func installEventSource(_ source: any WaylandThreadEventSource) throws {
        try executor.installEventSource(source)
    }

    func clearEventSource(_ source: (any WaylandThreadEventSource)?) {
        executor.clearEventSource(source)
    }

    func actorDidDeinitialize(lifecycle: inout WaylandDisplayLifecycle) {
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
