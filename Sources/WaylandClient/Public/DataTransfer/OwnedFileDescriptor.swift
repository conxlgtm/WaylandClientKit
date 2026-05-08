import Foundation
import Glibc
import WaylandRaw

public struct OwnedFileDescriptor: ~Copyable, Sendable {
    private static let readChunkByteCount = 16 * 1_024
    private static let asyncReadRetryInterval: Duration = .milliseconds(10)

    private var storage: Int32?
    private let readDescriptor: @Sendable (Int32, Int) throws -> [UInt8]
    private let prepareReadDescriptor: @Sendable (Int32) throws -> Void
    private let writeDescriptor: @Sendable (Int32, [UInt8]) throws -> Int
    private let closeDescriptor: @Sendable (Int32) -> Int32

    public init(adopting rawValue: Int32) throws {
        try self.init(
            adopting: rawValue,
            readDescriptor: Self.defaultReadDescriptor,
            writeDescriptor: Self.defaultWriteDescriptor,
            closeDescriptor: Self.defaultCloseDescriptor
        )
    }

    package init(
        adopting rawValue: Int32,
        readDescriptor read: @escaping @Sendable (Int32, Int) throws -> [UInt8] =
            Self.defaultReadDescriptor,
        prepareReadDescriptor prepareRead: @escaping @Sendable (Int32) throws -> Void =
            Self.defaultPrepareReadDescriptor,
        writeDescriptor write: @escaping @Sendable (Int32, [UInt8]) throws -> Int =
            Self.defaultWriteDescriptor,
        closeDescriptor close: @escaping @Sendable (Int32) -> Int32
    ) throws {
        guard rawValue >= 0 else {
            throw DataTransferError.invalidFileDescriptor(rawValue)
        }

        storage = rawValue
        readDescriptor = read
        prepareReadDescriptor = prepareRead
        writeDescriptor = write
        closeDescriptor = close
    }

    deinit {
        if let storage {
            _ = closeDescriptor(storage)
        }
    }
}

extension OwnedFileDescriptor {
    package var rawValue: Int32 {
        guard let storage else {
            preconditionFailure("file descriptor was already closed or released")
        }

        return storage
    }

    public var isClosed: Bool {
        storage == nil
    }

    public var description: String {
        guard let storage else {
            return "closed file descriptor"
        }

        return "file descriptor \(storage)"
    }

    public mutating func readData(
        limit: ByteCount = .defaultTransferReadLimit
    ) throws -> Data {
        let data: Data
        do {
            data = try readDataWithoutClosing(limit: limit)
        } catch {
            do {
                try close()
            } catch {
                _ = error
            }
            throw error
        }

        try close()
        return data
    }

    package mutating func readData(
        limit: ByteCount,
        timeout: Duration
    ) async throws -> Data {
        let data: Data
        do {
            data = try await readDataWithoutClosing(limit: limit, timeout: timeout)
        } catch is CancellationError {
            do {
                try close()
            } catch {
                _ = error
            }
            throw DataTransferError.cancelled
        } catch {
            do {
                try close()
            } catch {
                _ = error
            }
            throw error
        }

        try close()
        return data
    }

    public mutating func writeData(_ data: Data) throws {
        do {
            try writeDataWithoutClosing(data)
        } catch {
            do {
                try close()
            } catch {
                _ = error
            }
            throw error
        }

        try close()
    }

    public mutating func close() throws {
        guard let descriptor = storage else {
            return
        }

        storage = nil
        let closeErrno = closeDescriptor(descriptor)
        guard closeErrno == 0 else {
            throw DataTransferError.closeFileDescriptor(
                WaylandSystemErrno(unchecked: Self.normalizeErrno(closeErrno))
            )
        }
    }

    public mutating func releaseRawValue() -> Int32 {
        guard let descriptor = storage else {
            preconditionFailure("file descriptor was already closed or released")
        }

        storage = nil
        return descriptor
    }

    private mutating func readDataWithoutClosing(limit: ByteCount) throws -> Data {
        var data = Data()

        while true {
            let remainingByteCount = limit.rawValue - data.count
            let readByteCount = Self.nextReadByteCount(remainingByteCount)
            let bytes = try readDescriptor(rawValue, readByteCount)
            guard !bytes.isEmpty else {
                return data
            }
            guard bytes.count <= remainingByteCount else {
                throw DataTransferError.transferTooLarge(limit: limit)
            }

            data.append(contentsOf: bytes)
        }
    }

    private mutating func readDataWithoutClosing(
        limit: ByteCount,
        timeout: Duration
    ) async throws -> Data {
        try prepareReadDescriptor(rawValue)

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        var data = Data()

        while true {
            try Task.checkCancellation()

            let remainingByteCount = limit.rawValue - data.count
            let readByteCount = Self.nextReadByteCount(remainingByteCount)
            let bytes: [UInt8]
            do {
                bytes = try readDescriptor(rawValue, readByteCount)
            } catch let error as DataTransferError
                where Self.isTemporaryReadUnavailability(error)
            {
                try await Self.sleepBeforeReadRetry(clock: clock, deadline: deadline)
                continue
            }

            guard !bytes.isEmpty else {
                return data
            }
            guard bytes.count <= remainingByteCount else {
                throw DataTransferError.transferTooLarge(limit: limit)
            }

            data.append(contentsOf: bytes)
        }
    }

    private static func nextReadByteCount(_ remainingByteCount: Int) -> Int {
        let byteCountIncludingOverflowProbe =
            if remainingByteCount == Int.max {
                remainingByteCount
            } else {
                remainingByteCount + 1
            }

        return max(1, min(readChunkByteCount, byteCountIncludingOverflowProbe))
    }

    private static func sleepBeforeReadRetry(
        clock: ContinuousClock,
        deadline: ContinuousClock.Instant
    ) async throws {
        let remaining = clock.now.duration(to: deadline)
        guard remaining > .zero else {
            throw DataTransferError.transferTimedOut
        }

        let retryInterval = min(remaining, asyncReadRetryInterval)
        do {
            try await Task.sleep(for: retryInterval)
        } catch {
            throw DataTransferError.cancelled
        }
    }

    private static func isTemporaryReadUnavailability(
        _ error: DataTransferError
    ) -> Bool {
        guard case .readFileDescriptor(let systemError) = error else {
            return false
        }

        return systemError.rawValue == EAGAIN || systemError.rawValue == EWOULDBLOCK
    }

    private func writeDataWithoutClosing(_ data: Data) throws {
        let bytes = Array(data)
        var writtenByteCount = 0

        while writtenByteCount < bytes.count {
            let remainingBytes = Array(bytes[writtenByteCount...])
            let count = try writeDescriptor(rawValue, remainingBytes)
            guard count > 0, count <= remainingBytes.count else {
                throw DataTransferError.writeFileDescriptor(
                    WaylandSystemErrno(unchecked: EIO)
                )
            }

            writtenByteCount += count
        }
    }

    private static func defaultReadDescriptor(
        _ descriptor: Int32,
        maximumByteCount: Int
    ) throws -> [UInt8] {
        do {
            return try RawFileDescriptor.read(
                descriptor: descriptor,
                maximumByteCount: maximumByteCount
            )
        } catch {
            throw dataTransferReadError(error)
        }
    }

    private static func defaultPrepareReadDescriptor(_ descriptor: Int32) throws {
        guard descriptor >= 0 else {
            throw DataTransferError.invalidFileDescriptor(descriptor)
        }

        let flags = Glibc.fcntl(descriptor, F_GETFL)
        guard flags >= 0 else {
            throw DataTransferError.readFileDescriptor(
                WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
            )
        }
        guard Glibc.fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
            throw DataTransferError.readFileDescriptor(
                WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
            )
        }
    }

    private static func dataTransferReadError(_ error: RuntimeError) -> DataTransferError {
        switch error {
        case .system(let systemError):
            .readFileDescriptor(WaylandSystemErrno(unchecked: systemError.errno.rawValue))
        case .systemErrnoUnavailable:
            .readFileDescriptor(WaylandSystemErrno(unchecked: EIO))
        default:
            .unavailable
        }
    }

    private static func defaultWriteDescriptor(
        _ descriptor: Int32,
        bytes: [UInt8]
    ) throws -> Int {
        do {
            return try RawFileDescriptor.write(descriptor: descriptor, bytes: bytes)
        } catch {
            throw dataTransferWriteError(error)
        }
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

    private static func defaultCloseDescriptor(_ descriptor: Int32) -> Int32 {
        guard Glibc.close(descriptor) == 0 else {
            return normalizeErrno(errno)
        }

        return 0
    }

    private static func normalizeErrno(_ value: Int32) -> Int32 {
        value > 0 ? value : EIO
    }
}
