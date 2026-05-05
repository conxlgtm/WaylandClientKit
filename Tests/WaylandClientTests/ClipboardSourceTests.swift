import Foundation
import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct ClipboardSourceTests {
    @Test
    func settingSelectionSourceFromClipboardConfigurationUsesOrderedPayloads() throws {
        let seatID = SeatID(rawValue: 1)
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let configuration = try ClipboardSourceConfiguration(
            payloads: [
                ClipboardSourcePayload(
                    mimeType: .plainTextUTF8,
                    data: Data("hello".utf8)
                ),
                ClipboardSourcePayload(
                    mimeType: .uriList,
                    data: Data("file:///tmp/example\n".utf8)
                ),
            ]
        )

        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: configuration.mimeTypes,
            serial: InputSerial(rawValue: 45),
            dataProvider: configuration.dataProvider
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        #expect(sourceBinding.offeredMimeTypes == [.plainTextUTF8, .uriList])

        sourceBinding.emit(
            RawDataSourceEvent.send(mimeType: MIMEType.uriList.rawValue, fd: 190)
        )
        let requests = manager.drainSourceSendRequests()

        #expect(requests.map(\.mimeType) == [MIMEType.uriList])
        #expect(requests.map(\.data) == [Data("file:///tmp/example\n".utf8)])
        try requests.first?.close()
    }
}
