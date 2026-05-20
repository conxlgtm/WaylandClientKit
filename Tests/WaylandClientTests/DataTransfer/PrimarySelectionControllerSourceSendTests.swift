import Foundation
import Testing

@testable import WaylandClient

@Suite
struct PrimarySelectionControllerSourceSendTests {
    private let seat = SeatID(rawValue: 1)
    private let serial = InputSerial(rawValue: 55)

    @Test
    func sourceSendDrainsPrimarySelectionWriteJob() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let payloads = try primarySelectionPayloads([.plainText: Data("primary".utf8)])

        try controller.synchronizeSeats([seat])
        let snapshot = try controller.setSelectionSource(
            seatID: seat,
            payloads: payloads,
            serial: serial
        )
        try #require(backend.sourceBinding(for: snapshot.id)).emit(
            .send(mimeType: MIMEType.plainText.rawValue, fd: 78)
        )

        let jobs = try controller.drainSourceWriteJobs()
        let job = try #require(jobs.first)

        #expect(jobs.count == 1)
        #expect(controller.drainSourceSendRequests().isEmpty)
        #expect(
            job.write()
                == .succeeded(source: .primarySelection(snapshot.id), mimeType: .plainText)
        )
        #expect(
            backend.descriptorWrites
                == [
                    .init(
                        descriptor: 78,
                        bytes: Array("primary".utf8)
                    )
                ]
        )
        #expect(backend.closedDescriptors == [78])
    }

    @Test
    func sourceSendWithUnavailableMIMEClosesDescriptorAndRecordsCallbackFailure() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let payloads = try primarySelectionPayloads([.plainText: Data("primary".utf8)])

        try controller.synchronizeSeats([seat])
        let snapshot = try controller.setSelectionSource(
            seatID: seat,
            payloads: payloads,
            serial: serial
        )
        try #require(backend.sourceBinding(for: snapshot.id)).emit(
            .send(mimeType: MIMEType.uriList.rawValue, fd: 79)
        )

        #expect(
            throws: DataTransferCallbackFailure(
                context: .primarySelectionSource(
                    PrimarySelectionSourceIdentity(snapshot.id)
                ),
                error: .mimeTypeUnavailable(.uriList)
            )
        ) {
            try controller.throwPendingCallbackErrorIfAny()
        }
        #expect(backend.closedDescriptors == [79])
        #expect(controller.drainSourceSendRequests().isEmpty)
    }
}
