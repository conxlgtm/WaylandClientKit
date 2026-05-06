import Foundation
import Glibc
import Synchronization
import WaylandRaw

package final class DataTransferSourceWriteJob: Sendable {
    package let sourceID: DataSourceID
    package let mimeType: MIMEType
    package let data: Data

    private let descriptor: Mutex<DescriptorState>
    private let prepareDescriptorForWriting: @Sendable (Int32) throws -> Void
    private let writeDescriptor: @Sendable (Int32, [UInt8]) throws -> Int
    private let closeDescriptor: @Sendable (Int32) -> Int32

    package init(
        sourceID jobSourceID: DataSourceID,
        mimeType jobMIMEType: MIMEType,
        descriptor jobDescriptor: Int32,
        data jobData: Data,
        prepareDescriptorForWriting prepare: @escaping @Sendable (Int32) throws -> Void =
            DataTransferSourceWriteJob.defaultPrepareDescriptorForWriting,
        writeDescriptor write: @escaping @Sendable (Int32, [UInt8]) throws -> Int =
            DataTransferSourceWriteJob.defaultWriteDescriptor,
        closeDescriptor close: @escaping @Sendable (Int32) -> Int32 =
            DataTransferSourceWriteJob.defaultCloseDescriptor
    ) {
        sourceID = jobSourceID
        mimeType = jobMIMEType
        data = jobData
        descriptor = Mutex(DescriptorState(rawValue: jobDescriptor))
        prepareDescriptorForWriting = prepare
        writeDescriptor = write
        closeDescriptor = close
    }

    package func write() -> DataTransferSourceWriteResult {
        do {
            let rawDescriptor = try rawDescriptorForWriting()
            do {
                try prepareDescriptorForWriting(rawDescriptor)
                try writeData(to: rawDescriptor)
                try closeOwnedDescriptor(rawDescriptor)
            } catch {
                do {
                    try closeOwnedDescriptor(rawDescriptor)
                } catch {
                    _ = error
                }
                throw error
            }
            return .succeeded(sourceID: sourceID, mimeType: mimeType)
        } catch let error as DataTransferError {
            return .failed(sourceID: sourceID, mimeType: mimeType, error: error)
        } catch {
            return .failed(sourceID: sourceID, mimeType: mimeType, error: .unavailable)
        }
    }

    package func closeAsCancelled() -> DataTransferSourceWriteResult {
        do {
            try closeRawDescriptor(try releaseRawDescriptor())
            return .failed(sourceID: sourceID, mimeType: mimeType, error: .cancelled)
        } catch let error as DataTransferError {
            return .failed(sourceID: sourceID, mimeType: mimeType, error: error)
        } catch {
            return .failed(sourceID: sourceID, mimeType: mimeType, error: .unavailable)
        }
    }

    package func cancelInFlight() {
        let releasedDescriptor = descriptor.withLock { storage -> Int32? in
            storage.isCancellationRequested = true
            defer { storage.rawValue = nil }
            return storage.rawValue
        }
        if let releasedDescriptor {
            _ = closeDescriptor(releasedDescriptor)
        }
    }

    private func rawDescriptorForWriting() throws -> Int32 {
        try descriptor.withLock { storage in
            if storage.isCancellationRequested {
                throw DataTransferError.cancelled
            }
            guard let rawDescriptor = storage.rawValue else {
                throw DataTransferError.fileDescriptorAlreadyReleased
            }
            guard rawDescriptor >= 0 else {
                storage.rawValue = nil
                throw DataTransferError.invalidFileDescriptor(rawDescriptor)
            }

            return rawDescriptor
        }
    }

    private func writeData(to rawDescriptor: Int32) throws {
        let bytes = Array(data)
        var writtenByteCount = 0

        while writtenByteCount < bytes.count {
            try throwIfCancelled()
            let remainingBytes = Array(bytes[writtenByteCount...])
            do {
                let count = try writeDescriptor(rawDescriptor, remainingBytes)
                guard count > 0, count <= remainingBytes.count else {
                    throw DataTransferError.writeFileDescriptor(
                        WaylandSystemErrno(unchecked: EIO)
                    )
                }

                writtenByteCount += count
            } catch let error as DataTransferError {
                if isCancellationRequested() {
                    throw DataTransferError.cancelled
                }
                if Self.isTemporaryWriteBackpressure(error) {
                    usleep(1_000)
                    continue
                }

                throw error
            }
        }

        try throwIfCancelled()
    }

    private func throwIfCancelled() throws {
        if isCancellationRequested() {
            throw DataTransferError.cancelled
        }
    }

    private func isCancellationRequested() -> Bool {
        descriptor.withLock(\.isCancellationRequested)
    }

    private func releaseRawDescriptor() throws -> Int32 {
        let releasedDescriptor = takeRawDescriptor(markCancelled: false)
        guard let releasedDescriptor else {
            throw DataTransferError.fileDescriptorAlreadyReleased
        }

        return releasedDescriptor
    }

    private func closeOwnedDescriptor(_ rawDescriptor: Int32) throws {
        guard takeMatchingRawDescriptor(rawDescriptor) != nil else {
            if isCancellationRequested() {
                throw DataTransferError.cancelled
            }

            throw DataTransferError.fileDescriptorAlreadyReleased
        }

        let closeResult = closeDescriptor(rawDescriptor)
        guard closeResult == 0 else {
            throw DataTransferError.closeFileDescriptor(
                WaylandSystemErrno(unchecked: closeResult)
            )
        }
    }

    private func closeRawDescriptor(_ rawDescriptor: Int32) throws {
        let closeResult = closeDescriptor(rawDescriptor)
        guard closeResult == 0 else {
            throw DataTransferError.closeFileDescriptor(
                WaylandSystemErrno(unchecked: closeResult)
            )
        }
    }

    private func takeRawDescriptor(markCancelled: Bool) -> Int32? {
        descriptor.withLock { storage -> Int32? in
            if markCancelled {
                storage.isCancellationRequested = true
            }
            defer { storage.rawValue = nil }
            return storage.rawValue
        }
    }

    private func takeMatchingRawDescriptor(_ rawDescriptor: Int32) -> Int32? {
        descriptor.withLock { storage -> Int32? in
            guard storage.rawValue == rawDescriptor else {
                return nil
            }

            storage.rawValue = nil
            return rawDescriptor
        }
    }

    deinit {
        guard let releasedDescriptor = takeRawDescriptor(markCancelled: false) else {
            return
        }

        _ = closeDescriptor(releasedDescriptor)
    }

    private static func defaultPrepareDescriptorForWriting(_ descriptor: Int32) throws {
        guard descriptor >= 0 else {
            throw DataTransferError.invalidFileDescriptor(descriptor)
        }

        let flags = Glibc.fcntl(descriptor, F_GETFL)
        guard flags >= 0 else {
            throw DataTransferError.writeFileDescriptor(
                WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
            )
        }
        guard Glibc.fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
            throw DataTransferError.writeFileDescriptor(
                WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
            )
        }
    }

    private static func defaultWriteDescriptor(
        descriptor: Int32,
        bytes: [UInt8]
    ) throws -> Int {
        do {
            return try RawFileDescriptor.write(descriptor: descriptor, bytes: bytes)
        } catch let error {
            throw Self.dataTransferWriteError(error)
        }
    }

    private static func defaultCloseDescriptor(_ descriptor: Int32) -> Int32 {
        guard Glibc.close(descriptor) == 0 else {
            return errno > 0 ? errno : EIO
        }

        return 0
    }

    private static func dataTransferWriteError(_ error: RuntimeError) -> DataTransferError {
        switch error {
        case .system(let systemError):
            .writeFileDescriptor(WaylandSystemErrno(unchecked: systemError.errno.rawValue))
        case .systemErrnoUnavailable:
            .writeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
        default:
            .unavailable
        }
    }

    private static func isTemporaryWriteBackpressure(_ error: DataTransferError) -> Bool {
        guard case .writeFileDescriptor(let error) = error else {
            return false
        }

        return error.rawValue == EAGAIN || error.rawValue == EWOULDBLOCK
    }

    private struct DescriptorState: Sendable {
        var rawValue: Int32?
        var isCancellationRequested = false
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
        let currentJob: DataTransferSourceWriteJob?
        state.condition.lock()
        if state.isShutdown {
            cancelledJobs = []
            currentJob = state.currentJob
        } else {
            state.isShutdown = true
            cancelledJobs = state.jobs
            state.jobs.removeAll(keepingCapacity: false)
            currentJob = state.currentJob
            state.condition.broadcast()
        }
        state.condition.unlock()

        append(cancelledJobs.map { $0.closeAsCancelled() })
        currentJob?.cancelInFlight()
        waitUntilStopped()
    }

    deinit {
        shutdown()
    }

    private static func run(state: ThreadedDataTransferSourceWriterState) {
        defer {
            state.condition.lock()
            state.currentJob = nil
            state.isStopped = true
            state.condition.broadcast()
            state.condition.unlock()
        }

        while let job = nextJob(from: state) {
            let result = job.write()
            state.condition.lock()
            state.currentJob = nil
            state.results.append(result)
            state.condition.broadcast()
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

        let job = state.jobs.removeFirst()
        state.currentJob = job
        return job
    }

    private func append(_ results: [DataTransferSourceWriteResult]) {
        guard !results.isEmpty else { return }

        state.condition.lock()
        state.results.append(contentsOf: results)
        state.condition.broadcast()
        state.condition.unlock()
    }

    private func waitUntilStopped() {
        state.condition.lock()
        while !state.isStopped {
            state.condition.wait()
        }
        state.condition.unlock()
    }
}

// SAFETY: ThreadedDataTransferSourceWriterState is shared with exactly one worker thread.
// All mutable fields are accessed while holding `condition`, including shutdown and queues.
private final class ThreadedDataTransferSourceWriterState: @unchecked Sendable {
    let condition = NSCondition()
    var isShutdown = false
    var isStopped = false
    var currentJob: DataTransferSourceWriteJob?
    var jobs: [DataTransferSourceWriteJob] = []
    var results: [DataTransferSourceWriteResult] = []
}
