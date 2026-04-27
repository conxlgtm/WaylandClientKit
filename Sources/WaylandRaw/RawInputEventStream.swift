public struct RawInputEventStream: AsyncSequence {
    public typealias Element = RawInputEvent

    public static let defaultPollTimeoutMilliseconds: Int32 = 16

    private let timeoutMilliseconds: Int32
    private let pumpEvents: (Int32) throws -> [RawInputEvent]

    package init(
        timeoutMilliseconds streamTimeoutMilliseconds: Int32,
        pumpEvents streamPumpEvents: @escaping (Int32) throws -> [RawInputEvent]
    ) {
        timeoutMilliseconds = streamTimeoutMilliseconds
        pumpEvents = streamPumpEvents
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            timeoutMilliseconds: timeoutMilliseconds,
            pumpEvents: pumpEvents
        )
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private let timeoutMilliseconds: Int32
        private let pumpEvents: (Int32) throws -> [RawInputEvent]
        private var pendingEvents: [RawInputEvent] = []
        private var pendingIndex = 0
        private var isTerminated = false

        init(
            timeoutMilliseconds iteratorTimeoutMilliseconds: Int32,
            pumpEvents iteratorPumpEvents: @escaping (Int32) throws -> [RawInputEvent]
        ) {
            timeoutMilliseconds = iteratorTimeoutMilliseconds
            pumpEvents = iteratorPumpEvents
        }

        /// Returns the next event after performing blocking Wayland event pumps as needed.
        public mutating func next() async throws -> RawInputEvent? {
            guard !isTerminated else { return nil }

            let pollTimeoutMilliseconds = Swift.max(
                0,
                timeoutMilliseconds >= 0
                    ? timeoutMilliseconds
                    : RawInputEventStream.defaultPollTimeoutMilliseconds
            )

            while true {
                if pendingIndex < pendingEvents.count {
                    defer { pendingIndex += 1 }
                    return pendingEvents[pendingIndex]
                }

                if Task.isCancelled {
                    isTerminated = true
                    pendingEvents.removeAll(keepingCapacity: false)
                    return nil
                }

                do {
                    pendingEvents = try pumpEvents(pollTimeoutMilliseconds)
                } catch {
                    isTerminated = true
                    pendingEvents.removeAll(keepingCapacity: false)
                    throw error
                }
                pendingIndex = 0

                if pendingEvents.isEmpty {
                    await Task.yield()
                }
            }
        }
    }
}
