import Foundation
import Glibc
import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferReadableOfferTests {
    @Test
    func readableOfferReadsReceivedDescriptorPayload() async throws {
        let mimeType = try MIMEType("text/plain")
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        _ = try RawFileDescriptor.write(
            descriptor: descriptors.writeEnd,
            bytes: Array("payload".utf8)
        )
        Glibc.close(descriptors.writeEnd)

        let offer = TestReadableOffer(
            readEnd: descriptors.readEnd,
            expectedMIMEType: mimeType
        )

        let data = try await offer.readDataTransferPayload(
            mimeType,
            limit: try ByteCount.bytes(32),
            timeout: .seconds(1)
        )

        #expect(data == Data("payload".utf8))
    }

    private struct TestReadableOffer: DataTransferReadableOffer {
        let readEnd: Int32
        let expectedMIMEType: MIMEType

        func receive(_ mimeType: MIMEType) async throws -> OwnedFileDescriptor {
            #expect(mimeType == expectedMIMEType)
            return try OwnedFileDescriptor(adopting: readEnd)
        }
    }
}
