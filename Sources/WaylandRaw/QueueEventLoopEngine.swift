import Glibc

package protocol QueueEventLoopSource {
    associatedtype Failure: Error

    func dispatchPending() throws(Failure) -> Int32
    func prepareRead() throws(Failure) -> Bool
    func flush() throws(Failure) -> Bool
    func fileDescriptor() throws(Failure) -> CInt
    func readEvents() throws(Failure)
    func cancelRead()
    func pollFileDescriptors(
        _ descriptors: inout [pollfd],
        timeoutMilliseconds: Int32
    ) throws(Failure) -> Int32
    func pollFailed(errno: Int32) -> Failure
    func pollEventFailed(revents: Int16) -> Failure
}

package struct PreparedReadToken: ~Copyable {
    private var isResolved = false

    package init() {
        // The token starts unresolved and must be consumed by read or cancel.
    }

    package var needsResolution: Bool {
        !isResolved
    }

    package mutating func resolve() {
        precondition(!isResolved, "Prepared Wayland read resolved more than once")
        isResolved = true
    }

    deinit {
        precondition(isResolved, "Prepared Wayland read was neither read nor cancelled")
    }
}

package struct QueueEventLoopEngine {
    private static let pollFailureEvents = Int16(POLLERR) | Int16(POLLHUP) | Int16(POLLNVAL)

    package init() {
        // Stateless engine; instances only make call sites explicit.
    }

    package func step<Source: QueueEventLoopSource>(
        source: Source,
        timeoutMilliseconds: Int32,
        wakeFileDescriptor: CInt? = nil,
        drainWakeFileDescriptor: (() -> Void)? = nil
    ) throws(Source.Failure) {
        while try !source.prepareRead() {
            try drainPendingEvents(from: source)
        }

        var preparedRead = PreparedReadToken()
        do {
            let needsWriteWakeup = try source.flush()
            var descriptors = try pollDescriptors(
                source: source,
                needsWriteWakeup: needsWriteWakeup,
                wakeFileDescriptor: wakeFileDescriptor
            )
            let ready = try source.pollFileDescriptors(
                &descriptors,
                timeoutMilliseconds: timeoutMilliseconds
            )

            try handlePollResult(
                ready: ready,
                descriptors: descriptors,
                source: source,
                preparedRead: &preparedRead,
                drainWakeFileDescriptor: drainWakeFileDescriptor
            )

            try drainPendingEvents(from: source)
        } catch {
            if preparedRead.needsResolution {
                source.cancelRead()
                preparedRead.resolve()
            }
            throw error
        }
    }

    private func drainPendingEvents<Source: QueueEventLoopSource>(
        from source: Source
    ) throws(Source.Failure) {
        while try source.dispatchPending() > 0 {
            continue
        }
    }

    private func pollDescriptors<Source: QueueEventLoopSource>(
        source: Source,
        needsWriteWakeup: Bool,
        wakeFileDescriptor: CInt?
    ) throws(Source.Failure) -> [pollfd] {
        var waylandEvents = Int16(POLLIN)
        if needsWriteWakeup {
            waylandEvents |= Int16(POLLOUT)
        }

        var descriptors = [
            pollfd(fd: try source.fileDescriptor(), events: waylandEvents, revents: 0)
        ]

        if let wakeFileDescriptor {
            descriptors.append(
                pollfd(fd: wakeFileDescriptor, events: Int16(POLLIN), revents: 0)
            )
        }

        return descriptors
    }

    private func handlePollResult<Source: QueueEventLoopSource>(
        ready: Int32,
        descriptors: [pollfd],
        source: Source,
        preparedRead: inout PreparedReadToken,
        drainWakeFileDescriptor: (() -> Void)?
    ) throws(Source.Failure) {
        guard ready > 0 else {
            source.cancelRead()
            preparedRead.resolve()
            if ready < 0, errno != EINTR {
                throw source.pollFailed(errno: errno)
            }
            return
        }

        let wayland = descriptors[0]
        let wake = descriptors.count > 1 ? descriptors[1] : nil
        try throwIfPollFailed(
            wayland: wayland,
            wake: wake,
            source: source,
            preparedRead: &preparedRead
        )

        try readOrCancel(wayland: wayland, source: source, preparedRead: &preparedRead)

        if let wake, wake.revents & Int16(POLLIN) != 0 {
            drainWakeFileDescriptor?()
        }

        if wayland.revents & Int16(POLLOUT) != 0 {
            _ = try source.flush()
        }
    }

    private func throwIfPollFailed<Source: QueueEventLoopSource>(
        wayland: pollfd,
        wake: pollfd?,
        source: Source,
        preparedRead: inout PreparedReadToken
    ) throws(Source.Failure) {
        let waylandFailure = wayland.revents & Self.pollFailureEvents
        let wakeFailure = (wake?.revents ?? 0) & Self.pollFailureEvents
        guard waylandFailure == 0, wakeFailure == 0 else {
            source.cancelRead()
            preparedRead.resolve()
            let failedEvents = waylandFailure != 0 ? wayland.revents : wake?.revents ?? 0
            throw source.pollEventFailed(revents: failedEvents)
        }
    }

    private func readOrCancel<Source: QueueEventLoopSource>(
        wayland: pollfd,
        source: Source,
        preparedRead: inout PreparedReadToken
    ) throws(Source.Failure) {
        if wayland.revents & Int16(POLLIN) != 0 {
            preparedRead.resolve()
            try source.readEvents()
        } else {
            source.cancelRead()
            preparedRead.resolve()
        }
    }
}
