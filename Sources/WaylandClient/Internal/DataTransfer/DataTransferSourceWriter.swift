import Foundation
import Glibc
import Synchronization
import WaylandRaw

package struct DataTransferSourceDescriptorIO: Sendable {
    package static let raw = DataTransferSourceDescriptorIO()

    private let prepareDescriptorForWriting: @Sendable (Int32) throws -> Void
    private let writeDescriptor: @Sendable (Int32, [UInt8]) throws -> Int
    private let closeDescriptor: @Sendable (Int32) -> FileDescriptorCloseResult

    package init(
        prepareDescriptorForWriting prepare: @escaping @Sendable (Int32) throws -> Void =
            defaultPrepareDataTransferSourceDescriptorForWriting,
        writeDescriptor write: @escaping @Sendable (Int32, [UInt8]) throws -> Int =
            defaultWriteDataTransferSourceDescriptor,
        closeDescriptor close: @escaping @Sendable (Int32) -> FileDescriptorCloseResult =
            defaultCloseDataTransferSourceDescriptor
    ) {
        prepareDescriptorForWriting = prepare
        writeDescriptor = write
        closeDescriptor = close
    }

    package func prepareForWriting(_ descriptor: Int32) throws {
        try prepareDescriptorForWriting(descriptor)
    }
    package func write(_ descriptor: Int32, bytes: [UInt8]) throws -> Int {
        try writeDescriptor(descriptor, bytes)
    }
    package func close(_ descriptor: Int32) -> FileDescriptorCloseResult {
        closeDescriptor(descriptor)
    }
}

package enum DataTransferSourceWriteSource: Equatable, Sendable {
    case clipboard(DataSourceID)
    case primarySelection(DataSourceID)

    package var diagnosticSource: DataTransferDiagnosticSource {
        switch self {
        case .clipboard(let sourceID):
            .clipboard(ClipboardSourceIdentity(sourceID))
        case .primarySelection(let sourceID):
            .primarySelection(PrimarySelectionSourceIdentity(sourceID))
        }
    }

    package var sourceID: DataSourceID {
        switch self {
        case .clipboard(let sourceID), .primarySelection(let sourceID):
            sourceID
        }
    }
}

package final class DataTransferSourceWriteJob: Sendable {
    package let source: DataTransferSourceWriteSource
    package let mimeType: MIMEType
    package let data: Data

    package var sourceID: DataSourceID {
        source.sourceID
    }

    private let descriptor: Mutex<DataTransferSourceDescriptorState>
    private let descriptorIO: DataTransferSourceDescriptorIO
    private let writePolicy: DataTransferSourceWritePolicy

    package convenience init(
        sourceID jobSourceID: DataSourceID,
        mimeType jobMIMEType: MIMEType,
        descriptor jobDescriptor: Int32,
        data jobData: Data,
        writePolicy jobWritePolicy: DataTransferSourceWritePolicy = .default,
        prepareDescriptorForWriting prepare: @escaping @Sendable (Int32) throws -> Void =
            defaultPrepareDataTransferSourceDescriptorForWriting,
        writeDescriptor write: @escaping @Sendable (Int32, [UInt8]) throws -> Int =
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
        descriptor = Mutex(DataTransferSourceDescriptorState(rawValue: jobDescriptor))
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
        let bytes = Array(data)
        var writtenByteCount = 0
        var temporaryWriteFailureCount = 0

        while writtenByteCount < bytes.count {
            try throwIfCancelled()
            let remainingBytes = Array(bytes[writtenByteCount...])
            do {
                let count = try descriptorIO.write(rawDescriptor, bytes: remainingBytes)
                guard count > 0, count <= remainingBytes.count else {
                    throw DataTransferError.writeFileDescriptor(
                        WaylandSystemErrno(unchecked: EIO)
                    )
                }

                writtenByteCount += count
                temporaryWriteFailureCount = 0
            } catch let error as DataTransferError {
                if let cancellationError = cancellationError() {
                    throw cancellationError
                }
                if isTemporaryDataTransferSourceWriteBackpressure(error) {
                    temporaryWriteFailureCount += 1
                    guard
                        temporaryWriteFailureCount
                            <= writePolicy.maximumTemporaryWriteFailures
                    else {
                        throw DataTransferError.transferTimedOut
                    }
                    if writePolicy.retryDelayMicroseconds > 0 {
                        usleep(writePolicy.retryDelayMicroseconds)
                    }
                    continue
                }

                throw error
            }
        }

        try throwIfCancelled()
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
        switch descriptorIO.close(rawDescriptor) {
        case .closed:
            return .cancelled
        case .failed(let error):
            return .closeFileDescriptor(error)
        }
    }

    private func closeRawDescriptor(_ rawDescriptor: Int32) throws {
        switch descriptorIO.close(rawDescriptor) {
        case .closed:
            return
        case .failed(let error):
            throw DataTransferError.closeFileDescriptor(error)
        }
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

private func defaultPrepareDataTransferSourceDescriptorForWriting(_ descriptor: Int32) throws {
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

private func defaultWriteDataTransferSourceDescriptor(
    descriptor: Int32,
    bytes: [UInt8]
) throws -> Int {
    do {
        return try RawFileDescriptor.write(descriptor: descriptor, bytes: bytes)
    } catch let error {
        throw dataTransferSourceWriteError(error)
    }
}

private func defaultCloseDataTransferSourceDescriptor(
    _ descriptor: Int32
) -> FileDescriptorCloseResult {
    FileDescriptorCloseResult.posixReturn(Glibc.close(descriptor))
}

private func dataTransferSourceWriteError(_ error: RuntimeError) -> DataTransferError {
    switch error {
    case .system(let systemError):
        .writeFileDescriptor(WaylandSystemErrno(unchecked: systemError.errno.rawValue))
    case .systemErrnoUnavailable:
        .writeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
    default:
        .unavailable
    }
}

private func isTemporaryDataTransferSourceWriteBackpressure(
    _ error: DataTransferError
) -> Bool {
    guard case .writeFileDescriptor(let error) = error else {
        return false
    }

    return error.rawValue == EAGAIN || error.rawValue == EWOULDBLOCK
}

package enum DataTransferSourceWriteResult: Equatable, Sendable {
    case succeeded(source: DataTransferSourceWriteSource, mimeType: MIMEType)
    case failed(
        source: DataTransferSourceWriteSource,
        mimeType: MIMEType,
        error: DataTransferError
    )

    package static func succeeded(
        sourceID: DataSourceID,
        mimeType: MIMEType
    ) -> DataTransferSourceWriteResult {
        .succeeded(source: .clipboard(sourceID), mimeType: mimeType)
    }

    package static func failed(
        sourceID: DataSourceID,
        mimeType: MIMEType,
        error: DataTransferError
    ) -> DataTransferSourceWriteResult {
        .failed(source: .clipboard(sourceID), mimeType: mimeType, error: error)
    }
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
        if !state.lifecycle.acceptsJobs {
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
        if !state.lifecycle.acceptsJobs {
            cancelledJobs = []
            currentJob = state.currentJob
        } else {
            state.lifecycle = .shutdownRequested
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
            state.lifecycle = .stopped
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
            state.lifecycle.waitsForJobs
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
        while !state.lifecycle.isStopped {
            state.condition.wait()
        }
        state.condition.unlock()
    }
}
