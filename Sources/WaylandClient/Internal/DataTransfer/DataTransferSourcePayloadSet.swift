import Foundation
import Synchronization

package struct DataTransferSourcePayloadSet: Equatable, Sendable {
    package let payloads: [DataTransferSourcePayload]
    private let payloadsByMIMEType: [MIMEType: Data]

    package var mimeTypes: [MIMEType] {
        payloads.map(\.mimeType)
    }

    package init(payloads sourcePayloads: [DataTransferSourcePayload]) throws {
        payloads = sourcePayloads
        payloadsByMIMEType = try sourcePayloads.payloadsByMIMEType()
    }

    package init(data payloads: [MIMEType: Data]) throws {
        try self.init(payloads: payloads.sourcePayloadsSortedByMIMEType)
    }

    package func data(for mimeType: MIMEType) -> Data? {
        payloadsByMIMEType[mimeType]
    }
}

package final class DataTransferSourceSendRequest {
    package let source: DataTransferSourceWriteSource
    package let mimeType: MIMEType
    package let data: Data

    package var sourceID: DataSourceID {
        source.sourceID
    }

    private let descriptor: Mutex<Int32?>
    private let descriptorIO: DataTransferSourceDescriptorIO

    package init(
        source requestSource: DataTransferSourceWriteSource,
        mimeType requestMIMEType: MIMEType,
        descriptor rawDescriptor: Int32,
        data requestData: Data,
        descriptorIO requestDescriptorIO: DataTransferSourceDescriptorIO
    ) throws {
        guard rawDescriptor >= 0 else {
            throw DataTransferError.invalidFileDescriptor(rawDescriptor)
        }

        source = requestSource
        mimeType = requestMIMEType
        data = requestData
        descriptor = Mutex(rawDescriptor)
        descriptorIO = requestDescriptorIO
    }

    package func makeWriteJob() throws -> DataTransferSourceWriteJob {
        DataTransferSourceWriteJob(
            source: source,
            mimeType: mimeType,
            descriptor: try releaseRawDescriptor(),
            data: data,
            descriptorIO: descriptorIO
        )
    }

    package func releaseRawDescriptor() throws -> Int32 {
        let releasedDescriptor = descriptor.takeDescriptor()
        guard let releasedDescriptor else {
            throw DataTransferError.fileDescriptorAlreadyReleased
        }

        return releasedDescriptor
    }

    package func close() throws {
        let releasedDescriptor = try releaseRawDescriptor()
        try closeRawDescriptor(releasedDescriptor)
    }

    private func closeRawDescriptor(_ rawDescriptor: Int32) throws {
        guard rawDescriptor >= 0 else {
            throw DataTransferError.invalidFileDescriptor(rawDescriptor)
        }

        try descriptorIO.close(rawDescriptor).throwIfFailed()
    }

    deinit {
        guard let releasedDescriptor = descriptor.takeDescriptor() else {
            return
        }

        guard releasedDescriptor >= 0 else {
            return
        }

        _ = descriptorIO.close(releasedDescriptor)
    }
}

extension Array where Element == DataTransferSourcePayload {
    package var mimeTypes: [MIMEType] {
        map(\.mimeType)
    }

    package func payloadsByMIMEType() throws -> [MIMEType: Data] {
        try NonEmptyMIMETypeList.validate(
            mimeTypes,
            emptyError: .emptyDataSource
        )

        return Dictionary(
            uniqueKeysWithValues: map { payload in
                (payload.mimeType, payload.data)
            }
        )
    }
}

extension Dictionary where Key == MIMEType, Value == Data {
    package var sourcePayloadsSortedByMIMEType: [DataTransferSourcePayload] {
        keys.sorted { $0.rawValue < $1.rawValue }.map { mimeType in
            guard let data = self[mimeType] else {
                preconditionFailure("Payload dictionary key disappeared during iteration")
            }

            return DataTransferSourcePayload(mimeType: mimeType, data: data)
        }
    }
}
