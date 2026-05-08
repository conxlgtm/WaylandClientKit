import Glibc
import Testing

@testable import WaylandClient

@Suite
struct DataTransferManagerSourceCloseResultTests {
    private let seatID = SeatID(rawValue: 1)

    @Test
    func sourceSendCloseNegativeReturnReportsCloseError() throws {
        let backend = RecordingDataTransferBackend()
        backend.failingCloseDescriptors[204] = -1
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])

        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 79)
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(.send(mimeType: MIMEType.uriList.rawValue, fd: 204))

        #expect(backend.closedDescriptors == [204])
        #expect(
            throws: DataTransferCallbackFailure(
                context: .dataSource(ClipboardSourceIdentity(source.id)),
                error: .closeFileDescriptor(
                    WaylandSystemErrno(unchecked: EIO)
                )
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }
}
