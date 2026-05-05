import Foundation

package struct DataTransferSourceWriteJob: Equatable, Sendable {
    package let sourceID: DataSourceID
    package let mimeType: MIMEType
    package let descriptor: Int32
    package let data: Data

    package init(
        sourceID jobSourceID: DataSourceID,
        mimeType jobMIMEType: MIMEType,
        descriptor jobDescriptor: Int32,
        data jobData: Data
    ) {
        sourceID = jobSourceID
        mimeType = jobMIMEType
        descriptor = jobDescriptor
        data = jobData
    }

    package func write() -> DataTransferSourceWriteResult {
        do {
            var ownedDescriptor = try OwnedFileDescriptor(adopting: descriptor)
            try ownedDescriptor.writeData(data)
            return .succeeded(sourceID: sourceID, mimeType: mimeType)
        } catch let error as DataTransferError {
            return .failed(sourceID: sourceID, mimeType: mimeType, error: error)
        } catch {
            return .failed(sourceID: sourceID, mimeType: mimeType, error: .unavailable)
        }
    }

    package func closeAsCancelled() -> DataTransferSourceWriteResult {
        do {
            var ownedDescriptor = try OwnedFileDescriptor(adopting: descriptor)
            try ownedDescriptor.close()
            return .failed(sourceID: sourceID, mimeType: mimeType, error: .cancelled)
        } catch let error as DataTransferError {
            return .failed(sourceID: sourceID, mimeType: mimeType, error: error)
        } catch {
            return .failed(sourceID: sourceID, mimeType: mimeType, error: .unavailable)
        }
    }
}

package enum DataTransferSourceWriteResult: Equatable, Sendable {
    case succeeded(sourceID: DataSourceID, mimeType: MIMEType)
    case failed(sourceID: DataSourceID, mimeType: MIMEType, error: DataTransferError)
}

package protocol DataTransferSourceWriting: AnyObject {
    func submit(_ jobs: [DataTransferSourceWriteJob])
    func drainResults() -> [DataTransferSourceWriteResult]
    func shutdown()
}

package final class ThreadedDataTransferSourceWriter: DataTransferSourceWriting {
    private let state: ThreadedDataTransferSourceWriterState

    package init() {
        let writerState = ThreadedDataTransferSourceWriterState()
        state = writerState
        Thread.detachNewThread {
            Self.run(state: writerState)
        }
    }

    package func submit(_ jobs: [DataTransferSourceWriteJob]) {
        guard !jobs.isEmpty else { return }

        let cancelledJobs: [DataTransferSourceWriteJob]
        state.condition.lock()
        if state.isShutdown {
            cancelledJobs = jobs
        } else {
            state.jobs.append(contentsOf: jobs)
            cancelledJobs = []
            state.condition.signal()
        }
        state.condition.unlock()

        append(cancelledJobs.map { $0.closeAsCancelled() })
    }

    package func drainResults() -> [DataTransferSourceWriteResult] {
        state.condition.lock()
        defer { state.condition.unlock() }

        defer { state.results.removeAll(keepingCapacity: true) }
        return state.results
    }

    package func shutdown() {
        let cancelledJobs: [DataTransferSourceWriteJob]
        state.condition.lock()
        if state.isShutdown {
            cancelledJobs = []
        } else {
            state.isShutdown = true
            cancelledJobs = state.jobs
            state.jobs.removeAll(keepingCapacity: false)
            state.condition.broadcast()
        }
        state.condition.unlock()

        append(cancelledJobs.map { $0.closeAsCancelled() })
    }

    deinit {
        shutdown()
    }

    private static func run(state: ThreadedDataTransferSourceWriterState) {
        while let job = nextJob(from: state) {
            let result = job.write()
            state.condition.lock()
            state.results.append(result)
            state.condition.unlock()
        }
    }

    private static func nextJob(
        from state: ThreadedDataTransferSourceWriterState
    ) -> DataTransferSourceWriteJob? {
        state.condition.lock()
        defer { state.condition.unlock() }

        while state.jobs.isEmpty,
            !state.isShutdown
        {
            state.condition.wait()
        }

        guard !state.jobs.isEmpty else {
            return nil
        }

        return state.jobs.removeFirst()
    }

    private func append(_ results: [DataTransferSourceWriteResult]) {
        guard !results.isEmpty else { return }

        state.condition.lock()
        state.results.append(contentsOf: results)
        state.condition.unlock()
    }

    private func append(_ result: DataTransferSourceWriteResult) {
        append([result])
    }
}

// SAFETY: ThreadedDataTransferSourceWriterState is shared with exactly one worker thread.
// All mutable fields are accessed while holding `condition`, including shutdown and queues.
private final class ThreadedDataTransferSourceWriterState: @unchecked Sendable {
    let condition = NSCondition()
    var isShutdown = false
    var jobs: [DataTransferSourceWriteJob] = []
    var results: [DataTransferSourceWriteResult] = []
}
