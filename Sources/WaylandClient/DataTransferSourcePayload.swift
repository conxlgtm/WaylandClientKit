import Foundation
import Glibc
import Synchronization

package struct DataTransferSourceProvider: Sendable {
    private let payloadsByMIMEType: [MIMEType: Data]

    package init(data payloads: [MIMEType: Data]) {
        payloadsByMIMEType = payloads
    }

    package func data(for mimeType: MIMEType) -> Data? {
        payloadsByMIMEType[mimeType]
    }
}

package final class DataTransferSourceSendRequest {
    package let sourceID: DataSourceID
    package let mimeType: MIMEType
    package let data: Data

    private let descriptor: Mutex<Int32?>
    private let writeDescriptor: (Int32, [UInt8]) throws -> Int
    private let closeDescriptor: (Int32) -> Int32

    package init(
        sourceID requestSourceID: DataSourceID,
        mimeType requestMIMEType: MIMEType,
        descriptor rawDescriptor: Int32,
        data requestData: Data,
        writeDescriptor write: @escaping (Int32, [UInt8]) throws -> Int,
        closeDescriptor close: @escaping (Int32) -> Int32
    ) {
        sourceID = requestSourceID
        mimeType = requestMIMEType
        data = requestData
        descriptor = Mutex(rawDescriptor)
        writeDescriptor = write
        closeDescriptor = close
    }

    package func write() throws {
        let releasedDescriptor = try releaseRawDescriptor()
        do {
            try writeData(to: releasedDescriptor)
        } catch {
            let writeError = error
            do {
                try closeRawDescriptor(releasedDescriptor)
            } catch {
                _ = error
            }
            throw writeError
        }

        try closeRawDescriptor(releasedDescriptor)
    }

    package func makeWriteJob() throws -> DataTransferSourceWriteJob {
        DataTransferSourceWriteJob(
            sourceID: sourceID,
            mimeType: mimeType,
            descriptor: try releaseRawDescriptor(),
            data: data,
            writeDescriptor: writeDescriptor,
            closeDescriptor: closeDescriptor
        )
    }

    package func releaseRawDescriptor() throws -> Int32 {
        let releasedDescriptor = descriptor.withLock { storage -> Int32? in
            defer { storage = nil }
            return storage
        }
        guard let releasedDescriptor else {
            throw DataTransferError.fileDescriptorAlreadyReleased
        }

        return releasedDescriptor
    }

    package func close() throws {
        let releasedDescriptor = try releaseRawDescriptor()
        try closeRawDescriptor(releasedDescriptor)
    }

    private func writeData(to rawDescriptor: Int32) throws {
        let bytes = Array(data)
        var writtenByteCount = 0

        while writtenByteCount < bytes.count {
            let remainingBytes = Array(bytes[writtenByteCount...])
            let count = try writeDescriptor(rawDescriptor, remainingBytes)
            guard count > 0, count <= remainingBytes.count else {
                throw DataTransferError.writeFileDescriptor(
                    WaylandSystemErrno(unchecked: EIO)
                )
            }

            writtenByteCount += count
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

    deinit {
        guard
            let releasedDescriptor = descriptor.withLock({ storage -> Int32? in
                defer { storage = nil }
                return storage
            })
        else {
            return
        }

        _ = closeDescriptor(releasedDescriptor)
    }
}
