import Testing

@testable import WaylandClient

@Suite
struct DataTransferManagerCallbackFailureTests {
    private let seat1 = SeatID(rawValue: 1)

    @Test
    func callbackFailurePreservesBackendErrorTypeAndContext() {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        let error = UnexpectedCallbackError(message: "adopt offer failed with EIO")

        manager.recordCallbackError(error, context: .dataDevice(seat1))

        #expect(
            manager.pendingCallbackError
                == DataTransferCallbackFailure(
                    context: .dataDevice(seat1),
                    error: .callbackFailure(
                        .backend(
                            type: "UnexpectedCallbackError",
                            description: "adopt offer failed with EIO"
                        )
                    )
                )
        )
    }

    @Test
    func callbackFailurePreservesDataTransferError() {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)

        manager.recordCallbackError(
            DataTransferError.unknownSeat(seat1),
            context: .dataDevice(seat1)
        )

        #expect(
            manager.pendingCallbackError
                == DataTransferCallbackFailure(
                    context: .dataDevice(seat1),
                    error: .unknownSeat(seat1)
                )
        )
    }

    @Test
    func callbackErrorsAreQueuedInCallbackOrder() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        try manager.synchronizeSeats([])
        let releasedBinding = try #require(backend.binding(for: seat1))

        releasedBinding.emit(.selection(nil))
        releasedBinding.emit(.dataOffer(nil))

        #expect(
            manager.pendingCallbackError
                == DataTransferCallbackFailure(
                    context: .dataDevice(seat1),
                    error: .unknownSeat(seat1)
                )
        )
        #expect(
            throws: DataTransferCallbackFailure(
                context: .dataDevice(seat1),
                error: .unknownSeat(seat1)
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        #expect(
            manager.pendingCallbackError
                == DataTransferCallbackFailure(
                    context: .dataDevice(seat1),
                    error: .missingOfferHandle(seatID: seat1)
                )
        )
        #expect(
            throws: DataTransferCallbackFailure(
                context: .dataDevice(seat1),
                error: .missingOfferHandle(seatID: seat1)
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }
}

private struct UnexpectedCallbackError: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}
