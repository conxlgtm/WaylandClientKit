import Foundation
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
    private let closeDescriptor: (Int32) -> Int32

    package init(
        sourceID requestSourceID: DataSourceID,
        mimeType requestMIMEType: MIMEType,
        descriptor rawDescriptor: Int32,
        data requestData: Data,
        closeDescriptor close: @escaping (Int32) -> Int32
    ) {
        sourceID = requestSourceID
        mimeType = requestMIMEType
        data = requestData
        descriptor = Mutex(rawDescriptor)
        closeDescriptor = close
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
        let closeResult = closeDescriptor(releasedDescriptor)
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
