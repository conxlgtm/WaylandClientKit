import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferManagerReceiveTests {
    private let seat1 = SeatID(rawValue: 1)
    private let offerHandle1 = RawDataOfferHandle(uncheckedRawValue: 0xDADA_0001)

    @Test
    func receivingOfferPassesMimeTypeAndWriteDescriptorThenReturnsReadDescriptor() throws {
        let backend = RecordingDataTransferBackend()
        backend.pipeDescriptors = DataTransferPipeDescriptors(readEnd: 10, writeEnd: 11)
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer(MIMEType.plainTextUTF8.rawValue))
        try manager.checkInvariantsForTesting()
        device.emit(.selection(offerHandle1))
        try manager.checkInvariantsForTesting()

        var descriptor = try manager.receiveOffer(id: offer.id, mimeType: .plainTextUTF8)
        let rawDescriptor = descriptor.releaseRawValue()

        #expect(rawDescriptor == 10)
        #expect(
            offer.receives
                == [
                    RecordingDataTransferOfferBinding.Receive(
                        mimeType: .plainTextUTF8,
                        fd: 11
                    )
                ]
        )
        #expect(backend.closedDescriptors == [11])
    }

    @Test
    func receivingUnknownOfferIsRejectedBeforePipeCreation() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        #expect(throws: DataTransferError.unknownOffer) {
            _ = try manager.receiveOffer(
                id: DataOfferID(rawValue: 99),
                mimeType: .plainText
            )
        }

        #expect(backend.pipeCreationCount == 0)
    }

    @Test
    func runtimeOfferBindingIDMustMatchOfferID() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let offerID = DataOfferID(rawValue: 1)
        let mismatchedID = DataOfferID(rawValue: 99)

        manager.offerIDsByHandle[offerHandle1] = offerID
        manager.runtimeOffersByID[offerID] = .pending(
            handle: offerHandle1,
            binding: RecordingDataTransferOfferBinding(id: mismatchedID) { _ in
                return
            },
            seatID: seat1,
            mimeTypes: []
        )

        #expect(
            throws: DataTransferManagerInvariantViolation.runtimeOfferBindingIDMismatch(
                expected: offerID,
                actual: mismatchedID
            )
        ) {
            try manager.checkInvariantsForTesting()
        }
    }

    @Test
    func activeRuntimeOfferBindingIDMustMatchStateOfferID() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))
        try manager.checkInvariantsForTesting()

        let mismatchedID = DataOfferID(rawValue: offer.id.rawValue + 100)
        manager.runtimeOffersByID[offer.id] = .active(
            handle: offerHandle1,
            binding: RecordingDataTransferOfferBinding(id: mismatchedID) { _ in
                return
            }
        )

        #expect(
            throws: DataTransferManagerInvariantViolation.runtimeOfferBindingIDMismatch(
                expected: offer.id,
                actual: mismatchedID
            )
        ) {
            try manager.checkInvariantsForTesting()
        }
    }

    @Test
    func receivingUnavailableMimeTypeIsRejectedBeforePipeCreation() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer(MIMEType.plainText.rawValue))
        try manager.checkInvariantsForTesting()
        device.emit(.selection(offerHandle1))
        try manager.checkInvariantsForTesting()

        #expect(throws: DataTransferError.mimeTypeUnavailable(.uriList)) {
            _ = try manager.receiveOffer(id: offer.id, mimeType: .uriList)
        }

        #expect(backend.pipeCreationCount == 0)
        #expect(offer.receives.isEmpty)
    }

    @Test
    func receivePipeAdoptionFailureClosesBothDescriptors() throws {
        let backend = RecordingDataTransferBackend()
        backend.pipeDescriptors = DataTransferPipeDescriptors(readEnd: -1, writeEnd: 12)
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer(MIMEType.plainText.rawValue))
        try manager.checkInvariantsForTesting()
        device.emit(.selection(offerHandle1))
        try manager.checkInvariantsForTesting()

        #expect(throws: DataTransferError.invalidFileDescriptor(-1)) {
            _ = try manager.receiveOffer(id: offer.id, mimeType: .plainText)
        }

        #expect(backend.closedDescriptors == [-1, 12])
        #expect(offer.receives.isEmpty)
    }

    @Test
    func receiveWriteDescriptorAdoptionFailureClosesReadAndWriteDescriptors() throws {
        let backend = RecordingDataTransferBackend()
        backend.pipeDescriptors = DataTransferPipeDescriptors(readEnd: 13, writeEnd: 14)
        backend.failingDescriptorAdoptions.insert(14)
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer(MIMEType.plainText.rawValue))
        try manager.checkInvariantsForTesting()
        device.emit(.selection(offerHandle1))
        try manager.checkInvariantsForTesting()

        #expect(throws: DataTransferError.invalidFileDescriptor(14)) {
            _ = try manager.receiveOffer(id: offer.id, mimeType: .plainText)
        }

        #expect(backend.closedDescriptors == [14, 13])
        #expect(offer.receives.isEmpty)
    }
}
