import Foundation

package protocol DataTransferReadableOffer {
    func receive(_ mimeType: MIMEType) async throws -> OwnedFileDescriptor
}

extension DataTransferReadableOffer {
    package func readDataTransferPayload(
        _ mimeType: MIMEType,
        limit: ByteCount,
        timeout: Duration
    ) async throws -> Data {
        var descriptor = try await receive(mimeType)
        return try await descriptor.readData(limit: limit, timeout: timeout)
    }
}

extension ClipboardOffer: DataTransferReadableOffer {}
extension PrimarySelectionOffer: DataTransferReadableOffer {}
extension DragOffer: DataTransferReadableOffer {}
