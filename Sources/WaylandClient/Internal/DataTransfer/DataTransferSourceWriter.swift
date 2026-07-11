import Foundation
import WaylandRaw
import WaylandRuntime

// SAFETY: Descriptor state is private to one write job. All access is
// serialized through NSLock so ThreadSanitizer can observe cancellation and
// writer-thread synchronization.
@safe
private final class DataTransferSourceDescriptorStateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var state: DataTransferSourceDescriptorState

    init(_ initialState: DataTransferSourceDescriptorState) {
        state = initialState
    }

    func withLock<Result>(
        _ body: (inout DataTransferSourceDescriptorState) throws -> Result
    ) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&state)
    }
}

package final class DataTransferSourceWriteJob: Sendable {
    package let source: DataTransferSourceWriteSource
    package let mimeType: MIMEType
    package let data: Data

    package var sourceID: DataSourceID {
        source.sourceID
    }

    private let descriptor: DataTransferSourceDescriptorStateBox
    private let descriptorIO: DataTransferSourceDescriptorIO
    private let writePolicy: DataTransferSourceWritePolicy

    @safe
    package convenience init(
        sourceID jobSourceID: DataSourceID,
        mimeType jobMIMEType: MIMEType,
        descriptor jobDescriptor: Int32,
        data jobData: Data,
        writePolicy jobWritePolicy: DataTransferSourceWritePolicy = .default,
        prepareDescriptorForWriting prepare: @escaping @Sendable (Int32) throws -> Void =
            defaultPrepareDataTransferSourceDescriptorForWriting,
        writeDescriptor write:
            @escaping @Sendable (
                Int32,
                UnsafeRawBufferPointer
            ) throws -> Int =
            defaultWriteDataTransferSourceDescriptor,
        closeDescriptor close: @escaping @Sendable (Int32) -> FileDescriptorCloseResult =
            defaultCloseDataTransferSourceDescriptor
    ) {
        self.init(
            source: .clipboard(jobSourceID),
            mimeType: jobMIMEType,
            descriptor: jobDescriptor,
            data: jobData,
            descriptorIO: DataTransferSourceDescriptorIO(
                prepareDescriptorForWriting: prepare,
                writeDescriptor: write,
                closeDescriptor: close
            ),
            writePolicy: jobWritePolicy
        )
    }

    package init(
        source jobSource: DataTransferSourceWriteSource,
        mimeType jobMIMEType: MIMEType,
        descriptor jobDescriptor: Int32,
        data jobData: Data,
        descriptorIO jobDescriptorIO: DataTransferSourceDescriptorIO,
        writePolicy jobWritePolicy: DataTransferSourceWritePolicy = .default
    ) {
        source = jobSource
        mimeType = jobMIMEType
        data = jobData
        descriptor = DataTransferSourceDescriptorStateBox(
            DataTransferSourceDescriptorState(rawValue: jobDescriptor)
        )
        descriptorIO = jobDescriptorIO
        writePolicy = jobWritePolicy
    }

    package func write() -> DataTransferSourceWriteResult {
        do {
            let rawDescriptor = try startWriting()
            do {
                try descriptorIO.prepareForWriting(rawDescriptor)
                try writeData(to: rawDescriptor)
            } catch {
                let writeError = error
                do {
                    try closeOwnedDescriptor(rawDescriptor)
                } catch {
                    if Self.isCancellation(writeError) {
                        throw error
                    }
                }
                throw writeError
            }

            try closeOwnedDescriptor(rawDescriptor)
            return .succeeded(source: source, mimeType: mimeType)
        } catch let error as DataTransferError {
            return .failed(source: source, mimeType: mimeType, error: error)
        } catch {
            return .failed(source: source, mimeType: mimeType, error: .unavailable)
        }
    }

    package func closeAsCancelled() -> DataTransferSourceWriteResult {
        do {
            try closeRawDescriptor(try releaseRawDescriptor())
            return .failed(source: source, mimeType: mimeType, error: .cancelled)
        } catch let error as DataTransferError {
            return .failed(source: source, mimeType: mimeType, error: error)
        } catch {
            return .failed(source: source, mimeType: mimeType, error: .unavailable)
        }
    }

    package func cancelInFlight() {
        descriptor.withLock { state in
            switch state {
            case .idle(let rawDescriptor):
                state = .cancelledBeforeWriting(closeCancellationDescriptor(rawDescriptor))
            case .writing(let rawDescriptor, nil):
                state = .writing(rawDescriptor, cancellationError: .cancelled)
            case .writing(_, .some), .cancelledBeforeWriting, .consumed:
                break
            }
        }
    }

    private func startWriting() throws -> Int32 {
        try descriptor.withLock { storage in
            switch storage {
            case .idle(let rawDescriptor):
                guard rawDescriptor >= 0 else {
                    storage = .consumed
                    throw DataTransferError.invalidFileDescriptor(rawDescriptor)
                }

                storage = .writing(rawDescriptor, cancellationError: nil)
                return rawDescriptor
            case .cancelledBeforeWriting(let error):
                storage = .consumed
                throw error
            case .writing, .consumed:
                throw DataTransferError.fileDescriptorAlreadyReleased
            }
        }
    }

    private func writeData(to rawDescriptor: Int32) throws {
        try unsafe DescriptorDataWriter.writeAll(
            data,
            to: rawDescriptor,
            write: descriptorIO.write,
            shouldCancel: throwIfCancelled,
            temporaryFailurePolicy: writePolicy
        )
    }

    private func throwIfCancelled() throws {
        if let error = cancellationError() {
            throw error
        }
    }

    private func cancellationError() -> DataTransferError? {
        descriptor.withLock { storage in
            switch storage {
            case .writing(_, let cancellationError):
                cancellationError
            case .cancelledBeforeWriting(let error):
                error
            case .idle, .consumed:
                nil
            }
        }
    }

    private func releaseRawDescriptor() throws -> Int32 {
        let releasedDescriptor = takeIdleRawDescriptor()
        guard let releasedDescriptor else {
            throw DataTransferError.fileDescriptorAlreadyReleased
        }

        return releasedDescriptor
    }

    private func closeOwnedDescriptor(_ rawDescriptor: Int32) throws {
        let cancellationError = try descriptor.withLock { storage -> DataTransferError? in
            switch storage {
            case .writing(rawDescriptor, let cancellationError):
                storage = .consumed
                return cancellationError
            case .idle, .writing, .cancelledBeforeWriting, .consumed:
                throw DataTransferError.fileDescriptorAlreadyReleased
            }
        }
        try closeRawDescriptor(rawDescriptor)
        if let cancellationError {
            throw cancellationError
        }
    }

    private func closeCancellationDescriptor(_ rawDescriptor: Int32) -> DataTransferError {
        guard rawDescriptor >= 0 else {
            return .invalidFileDescriptor(rawDescriptor)
        }

        switch descriptorIO.close(rawDescriptor) {
        case .closed:
            return .cancelled
        case .failed(let error):
            return .closeFileDescriptor(error)
        }
    }

    private func closeRawDescriptor(_ rawDescriptor: Int32) throws {
        guard rawDescriptor >= 0 else {
            throw DataTransferError.invalidFileDescriptor(rawDescriptor)
        }

        try descriptorIO.close(rawDescriptor).throwIfFailed()
    }

    private func takeIdleRawDescriptor() -> Int32? {
        descriptor.withLock { storage -> Int32? in
            switch storage {
            case .idle(let rawDescriptor):
                storage = .consumed
                return rawDescriptor
            case .cancelledBeforeWriting:
                storage = .consumed
                return nil
            case .writing, .consumed:
                return nil
            }
        }
    }

    private func closeDescriptorOnDeinit() {
        let rawDescriptor = descriptor.withLock { storage -> Int32? in
            switch storage {
            case .idle(let rawDescriptor), .writing(let rawDescriptor, nil):
                storage = .consumed
                return rawDescriptor
            case .writing(_, .some), .cancelledBeforeWriting, .consumed:
                storage = .consumed
                return nil
            }
        }
        if let rawDescriptor {
            guard rawDescriptor >= 0 else {
                return
            }

            _ = descriptorIO.close(rawDescriptor)
        }
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        guard let dataTransferError = error as? DataTransferError else {
            return false
        }

        return dataTransferError == .cancelled
    }

    deinit {
        closeDescriptorOnDeinit()
    }
}

package final class ThreadedDataTransferSourceWriter {
    private enum Lifecycle {
        case running
        case shutdownRequested
        case stopped

        var acceptsJobs: Bool {
            self == .running
        }

        var waitsForJobs: Bool {
            self == .running
        }

        var isStopped: Bool {
            self == .stopped
        }
    }

    // SAFETY: State is shared with exactly one worker thread. Its mutable
    // storage is private, and every state transition happens while holding
    // `condition`.
    private final class State: @unchecked Sendable {
        private let condition = NSCondition()
        private var lifecycle = Lifecycle.running
        private var currentJob: DataTransferSourceWriteJob?
        private var jobs: FIFOQueue<DataTransferSourceWriteJob> = []
        private var results: [DataTransferSourceWriteResult] = []

        func submit(_ submittedJobs: [DataTransferSourceWriteJob])
            -> [DataTransferSourceWriteJob]
        {
            condition.withLock {
                guard lifecycle.acceptsJobs else {
                    return submittedJobs
                }

                jobs.append(contentsOf: submittedJobs)
                condition.signal()
                return []
            }
        }

        func drainResults() -> [DataTransferSourceWriteResult] {
            condition.withLock {
                results.drain()
            }
        }

        func requestShutdown() -> (
            cancelledJobs: [DataTransferSourceWriteJob],
            currentJob: DataTransferSourceWriteJob?
        ) {
            condition.withLock {
                guard lifecycle.acceptsJobs else {
                    return (cancelledJobs: [], currentJob: currentJob)
                }

                lifecycle = .shutdownRequested
                let cancelledJobs = jobs.drain(keepingCapacity: false)
                condition.broadcast()
                return (cancelledJobs: cancelledJobs, currentJob: currentJob)
            }
        }

        func cancelJobs(for source: DataTransferSourceWriteSource) -> (
            cancelledJobs: [DataTransferSourceWriteJob],
            currentJob: DataTransferSourceWriteJob?
        ) {
            condition.withLock {
                guard !lifecycle.isStopped else {
                    return (cancelledJobs: [], currentJob: nil)
                }

                let cancelledJobs = jobs.removeAllReturning { $0.source == source }

                let currentJob = currentJob?.source == source ? currentJob : nil
                condition.broadcast()
                return (cancelledJobs: cancelledJobs, currentJob: currentJob)
            }
        }

        func markStopped() {
            condition.withLock {
                currentJob = nil
                lifecycle = .stopped
                condition.broadcast()
            }
        }

        func completeCurrentJob(with result: DataTransferSourceWriteResult) {
            condition.withLock {
                currentJob = nil
                results.append(result)
                condition.broadcast()
            }
        }

        func nextJob() -> DataTransferSourceWriteJob? {
            condition.withLock {
                while jobs.isEmpty,
                    lifecycle.waitsForJobs
                {
                    condition.wait()
                }

                guard let job = jobs.popFirst() else {
                    return nil
                }
                currentJob = job
                return job
            }
        }

        func append(_ newResults: [DataTransferSourceWriteResult]) {
            guard !newResults.isEmpty else { return }

            condition.withLock {
                results.append(contentsOf: newResults)
                condition.broadcast()
            }
        }

        func waitUntilStopped() {
            condition.withLock {
                while !lifecycle.isStopped {
                    condition.wait()
                }
            }
        }
    }

    private let state: State

    package init() {
        let writerState = State()
        state = writerState
        Thread.detachNewThread {
            Self.run(state: writerState)
        }
    }

    package func submit(_ jobs: [DataTransferSourceWriteJob]) {
        guard !jobs.isEmpty else { return }

        let cancelledJobs = state.submit(jobs)
        append(cancelledJobs.map { $0.closeAsCancelled() })
    }

    package func drainResults() -> [DataTransferSourceWriteResult] {
        state.drainResults()
    }

    package func cancelJobs(for source: DataTransferSourceWriteSource) {
        let cancellation = state.cancelJobs(for: source)
        append(cancellation.cancelledJobs.map { $0.closeAsCancelled() })
        cancellation.currentJob?.cancelInFlight()
    }

    package func shutdown() {
        let shutdown = state.requestShutdown()
        append(shutdown.cancelledJobs.map { $0.closeAsCancelled() })
        shutdown.currentJob?.cancelInFlight()
        waitUntilStopped()
    }

    deinit {
        shutdown()
    }

    private static func run(state: State) {
        defer {
            state.markStopped()
        }

        while let job = state.nextJob() {
            let result = job.write()
            state.completeCurrentJob(with: result)
        }
    }

    private func append(_ results: [DataTransferSourceWriteResult]) {
        state.append(results)
    }

    private func waitUntilStopped() {
        state.waitUntilStopped()
    }
}
