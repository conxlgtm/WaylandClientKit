import Glibc
import WaylandRaw

package struct DataTransferSourceDescriptorIO: Sendable {
    package static let raw = DataTransferSourceDescriptorIO()

    private let prepareDescriptorForWriting: @Sendable (Int32) throws -> Void
    private let writeDescriptor: @Sendable (Int32, ArraySlice<UInt8>) throws -> Int
    private let closeDescriptor: @Sendable (Int32) -> FileDescriptorCloseResult

    package init(
        prepareDescriptorForWriting prepare: @escaping @Sendable (Int32) throws -> Void =
            defaultPrepareDataTransferSourceDescriptorForWriting,
        writeDescriptor write: @escaping @Sendable (Int32, ArraySlice<UInt8>) throws -> Int =
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

    package func write(_ descriptor: Int32, bytes: ArraySlice<UInt8>) throws -> Int {
        try writeDescriptor(descriptor, bytes)
    }

    package func close(_ descriptor: Int32) -> FileDescriptorCloseResult {
        closeDescriptor(descriptor)
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
            WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
        )
    }
    guard Glibc.fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
        throw DataTransferError.writeFileDescriptor(
            WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
        )
    }
}

package func defaultWriteDataTransferSourceDescriptor(
    descriptor: Int32,
    bytes: ArraySlice<UInt8>
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
