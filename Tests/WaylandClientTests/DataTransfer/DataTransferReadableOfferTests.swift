import Foundation
import Synchronization
import Testing

@testable import WaylandClient

@Suite
struct DataTransferReadableOfferTests {
    @Test
    func readableOfferReadsReceivedDescriptorPayload() async throws {
        let offer = TestReadableOffer()
        let mimeType = try MIMEType("text/plain")

        let data = try await offer.readDataTransferPayload(
            mimeType,
            limit: try ByteCount.bytes(32),
            timeout: .seconds(1)
        )

        #expect(data == Data("payload".utf8))
        #expect(offer.receivedMIMETypes.withLock { $0 } == [mimeType])
        #expect(offer.closedDescriptors.withLock { $0 } == [71])
    }

    private final class TestReadableOffer: DataTransferReadableOffer, Sendable {
        let receivedMIMETypes = Mutex<[MIMEType]>([])
        let closedDescriptors = Mutex<[Int32]>([])
        private let readSteps = Mutex<[[UInt8]]>([
            Array("payload".utf8),
            [],
        ])

        func receive(_ mimeType: MIMEType) async throws -> OwnedFileDescriptor {
            receivedMIMETypes.withLock { $0.append(mimeType) }
            return try OwnedFileDescriptor(
                adopting: 71,
                readDescriptor: { [readSteps] _, _ in
                    readSteps.withLock { steps in
                        steps.isEmpty ? [] : steps.removeFirst()
                    }
                },
                closeDescriptor: { [closedDescriptors] descriptor in
                    closedDescriptors.withLock { $0.append(descriptor) }
                    return 0
                }
            )
        }
    }
}
