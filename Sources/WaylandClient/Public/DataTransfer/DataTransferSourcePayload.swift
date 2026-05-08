import Foundation

public struct DataTransferSourcePayload: Equatable, Sendable {
    public let mimeType: MIMEType
    public let data: Data

    public init(mimeType payloadMIMEType: MIMEType, data payloadData: Data) {
        mimeType = payloadMIMEType
        data = payloadData
    }
}

public typealias ClipboardSourcePayload = DataTransferSourcePayload
