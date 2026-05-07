import Testing

@testable import WaylandClient

@Suite
struct DataTransferManagerCallbackFailureTests {
    private let seat1 = SeatID(rawValue: 1)

    @Test
    func unexpectedCallbackErrorPreservesMessageAndContext() {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        let error = UnexpectedCallbackError(message: "adopt offer failed with EIO")

        manager.recordCallbackError(error, context: .dataDevice(seat1))

        #expect(
            manager.pendingCallbackError
                == DataTransferCallbackFailure(
                    context: .dataDevice(seat1),
                    error: .callbackFailure("adopt offer failed with EIO")
                )
        )
    }
}

private struct UnexpectedCallbackError: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}
