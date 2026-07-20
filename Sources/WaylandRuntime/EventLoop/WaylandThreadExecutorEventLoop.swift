import WaylandRaw

extension WaylandThreadExecutor {
    func runEventSourceTurn(
        _ source: any WaylandThreadEventSource,
        timeoutMilliseconds: Int32
    ) throws {
        try QueueEventLoopEngine().step(
            source: source,
            timeoutMilliseconds: timeoutMilliseconds,
            wakeFileDescriptor: wakeFileDescriptor
        ) { [weak executor = self] in
            executor?.drainWakeFileDescriptor()
        }
    }
}
