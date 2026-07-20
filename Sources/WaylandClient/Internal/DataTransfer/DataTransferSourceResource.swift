import Foundation

extension DataTransferSourceResourceBinding {
    func validateID(_ expectedSourceID: DataSourceID) throws {
        guard id == expectedSourceID else {
            throw DataTransferManagerInvariantViolation.sourceBindingIDMismatch(
                expected: expectedSourceID,
                actual: id
            )
        }
    }

    func offer(_ mimeTypes: [MIMEType]) {
        for mimeType in mimeTypes {
            offer(mimeType: mimeType)
        }
    }
}

struct PreparedDataTransferSourceSend {
    let request: DataTransferSourceSendRequest
    let event: DataTransferEvent

    init(
        source: DataTransferSourceWriteSource,
        snapshot: DataSourceSnapshot,
        data: Data?,
        mimeType: MIMEType,
        descriptor: Int32,
        descriptorIO: DataTransferSourceDescriptorIO
    ) throws {
        guard snapshot.mimeTypes.contains(mimeType) else {
            throw DataTransferError.mimeTypeUnavailable(mimeType)
        }
        guard let data else {
            throw DataTransferError.sourceDataUnavailable(mimeType)
        }

        request = try DataTransferSourceSendRequest(
            source: source,
            mimeType: mimeType,
            descriptor: descriptor,
            data: data,
            descriptorIO: descriptorIO
        )
        event = .sourceSendRequested(
            DataTransferSourceTransferEvent(
                source: source.diagnosticSource,
                mimeType: mimeType
            )
        )
    }
}
