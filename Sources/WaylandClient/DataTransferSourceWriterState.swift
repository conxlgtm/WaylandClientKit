import Foundation

package enum ThreadedDataTransferSourceWriterLifecycle {
    case running
    case shutdownRequested
    case stopped

    package var acceptsJobs: Bool {
        self == .running
    }

    package var waitsForJobs: Bool {
        self == .running
    }

    package var isStopped: Bool {
        self == .stopped
    }
}

// SAFETY: ThreadedDataTransferSourceWriterState is shared with exactly one worker thread.
// All mutable fields are accessed while holding `condition`, including shutdown and queues.
package final class ThreadedDataTransferSourceWriterState: @unchecked Sendable {
    let condition = NSCondition()
    var lifecycle = ThreadedDataTransferSourceWriterLifecycle.running
    var currentJob: DataTransferSourceWriteJob?
    var jobs: [DataTransferSourceWriteJob] = []
    var results: [DataTransferSourceWriteResult] = []
}
