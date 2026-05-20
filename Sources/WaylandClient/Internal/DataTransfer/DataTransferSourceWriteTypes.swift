import Foundation
import Glibc
import WaylandRaw

@safe
package struct DataTransferSourceDescriptorIO: Sendable {
    package static let raw = DataTransferSourceDescriptorIO()

    private let prepareDescriptorForWriting: @Sendable (Int32) throws -> Void
    private let writeDescriptor: @Sendable (Int32, UnsafeRawBufferPointer) throws -> Int
    private let closeDescriptor: @Sendable (Int32) -> FileDescriptorCloseResult

    @safe
    package init(
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
        prepareDescriptorForWriting = prepare
        unsafe writeDescriptor = write
        closeDescriptor = close
    }

    package func prepareForWriting(_ descriptor: Int32) throws {
        try prepareDescriptorForWriting(descriptor)
    }

    package func write(_ descriptor: Int32, bytes: UnsafeRawBufferPointer) throws -> Int {
        try unsafe writeDescriptor(descriptor, bytes)
    }

    package func close(_ descriptor: Int32) -> FileDescriptorCloseResult {
        closeDescriptor(descriptor)
    }
}

package enum DescriptorDataWriter {
    @safe
    package static func writeAll(
        _ data: Data,
        to descriptor: Int32,
        write: (Int32, UnsafeRawBufferPointer) throws -> Int,
        shouldCancel: () throws -> Void = {
            // Callers without cancellation state can use this default.
        },
        temporaryFailurePolicy: DataTransferSourceWritePolicy? = nil
    ) throws {
        try unsafe data.withUnsafeBytes { bytes in
            try writeAllBytes(
                bytes,
                to: descriptor,
                write: write,
                shouldCancel: shouldCancel,
                temporaryFailurePolicy: temporaryFailurePolicy
            )
        }

        try shouldCancel()
    }

    @safe
    private static func writeAllBytes(
        _ bytes: UnsafeRawBufferPointer,
        to descriptor: Int32,
        write: (Int32, UnsafeRawBufferPointer) throws -> Int,
        shouldCancel: () throws -> Void,
        temporaryFailurePolicy: DataTransferSourceWritePolicy?
    ) throws {
        var writtenByteCount = 0
        var temporaryWriteFailureCount = 0

        while writtenByteCount < bytes.count {
            try shouldCancel()
            let remainingBytes = unsafe UnsafeRawBufferPointer(
                rebasing: bytes[writtenByteCount...]
            )

            do {
                let count = try unsafe write(descriptor, remainingBytes)
                guard count > 0, count <= remainingBytes.count else {
                    throw DataTransferError.writeFileDescriptor(
                        WaylandSystemErrno(unchecked: EIO)
                    )
                }

                writtenByteCount += count
                temporaryWriteFailureCount = 0
            } catch let error as DataTransferError {
                if let cancellationError = try cancellationError(shouldCancel) {
                    throw cancellationError
                }
                if let temporaryFailurePolicy,
                    isTemporaryDataTransferSourceWriteBackpressure(error)
                {
                    temporaryWriteFailureCount += 1
                    guard
                        temporaryWriteFailureCount
                            <= temporaryFailurePolicy.maximumTemporaryWriteFailures
                    else {
                        throw DataTransferError.transferTimedOut
                    }
                    if temporaryFailurePolicy.retryDelayMicroseconds > 0 {
                        usleep(temporaryFailurePolicy.retryDelayMicroseconds)
                    }
                    continue
                }

                throw error
            }
        }
    }

    private static func cancellationError(_ shouldCancel: () throws -> Void) throws
        -> DataTransferError?
    {
        do {
            try shouldCancel()
            return nil
        } catch let error as DataTransferError {
            return error
        } catch {
            throw error
        }
    }
}

package enum DataTransferSourceWriteSource: Equatable, Sendable {
    case clipboard(DataSourceID)
    case primarySelection(DataSourceID)
    case dragAndDrop(DataSourceID)

    package var diagnosticSource: DataTransferDiagnosticSource {
        switch self {
        case .clipboard(let sourceID):
            .clipboard(sourceID.clipboardIdentity)
        case .primarySelection(let sourceID):
            .primarySelection(sourceID.primarySelectionIdentity)
        case .dragAndDrop(let sourceID):
            .dragAndDrop(sourceID.dragIdentity)
        }
    }

    package var sourceID: DataSourceID {
        switch self {
        case .clipboard(let sourceID), .primarySelection(let sourceID),
            .dragAndDrop(let sourceID):
            sourceID
        }
    }
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

package func defaultPrepareDataTransferSourceDescriptorForWriting(
    _ descriptor: Int32
) throws {
    guard descriptor >= 0 else {
        throw DataTransferError.invalidFileDescriptor(descriptor)
    }

    let flags = Glibc.fcntl(descriptor, F_GETFL)
    guard flags >= 0 else {
        throw DataTransferError.writeFileDescriptor(
            WaylandSystemErrno(capturingPOSIXErrno: errno, fallback: EIO)
        )
    }
    guard Glibc.fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
        throw DataTransferError.writeFileDescriptor(
            WaylandSystemErrno(capturingPOSIXErrno: errno, fallback: EIO)
        )
    }
}

@safe
package func defaultWriteDataTransferSourceDescriptor(
    descriptor: Int32,
    bytes: UnsafeRawBufferPointer
) throws -> Int {
    do {
        return try RawFileDescriptor.write(descriptor: descriptor, bytes: bytes)
    } catch let error {
        throw dataTransferSourceWriteError(error)
    }
}

package func defaultCloseDataTransferSourceDescriptor(
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
