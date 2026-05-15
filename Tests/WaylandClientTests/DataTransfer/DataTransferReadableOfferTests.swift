import Foundation
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
        #expect(offer.receivedMIMETypes == [mimeType])
        #expect(offer.closedDescriptors == [71])
    }

    private final class TestReadableOffer: DataTransferReadableOffer, @unchecked Sendable {
        private let lock = NSLock()
        private var receivedMIMETypesStorage: [MIMEType] = []
        private var closedDescriptorsStorage: [Int32] = []
        private var readSteps: [[UInt8]] = [
            Array("payload".utf8),
            [],
        ]

        var receivedMIMETypes: [MIMEType] {
            withLocked {
                receivedMIMETypesStorage
            }
        }

        var closedDescriptors: [Int32] {
            withLocked {
                closedDescriptorsStorage
            }
        }

        func receive(_ mimeType: MIMEType) async throws -> OwnedFileDescriptor {
            withLocked {
                receivedMIMETypesStorage.append(mimeType)
            }
            return try OwnedFileDescriptor(
                adopting: 71,
                readDescriptor: { [self] _, _ in
                    nextReadStep()
                },
                closeDescriptor: { [self] descriptor in
                    recordClosedDescriptor(descriptor)
                    return 0
                }
            )
        }

        private func nextReadStep() -> [UInt8] {
            withLocked {
                readSteps.isEmpty ? [] : readSteps.removeFirst()
            }
        }

        private func recordClosedDescriptor(_ descriptor: Int32) {
            withLocked {
                closedDescriptorsStorage.append(descriptor)
            }
        }

        private func withLocked<Result>(_ body: () throws -> Result) rethrows -> Result {
            lock.lock()
            defer { lock.unlock() }
            return try body()
        }
    }
}
