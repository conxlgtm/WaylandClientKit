import Testing

@testable import WaylandClient

@Suite
struct DataTransferManagerSourceTests {
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)

    @Test
    func settingSelectionSourceOffersMimeTypesAndSetsDataDeviceSelection() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText, .plainTextUTF8],
            serial: InputSerial(rawValue: 44)
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        let expectedSource = try DataSourceSnapshot(
            id: DataSourceID(rawValue: 1),
            seatID: seat1,
            mimeTypes: [.plainText, .plainTextUTF8]
        )

        #expect(source == expectedSource)
        #expect(sourceBinding.offeredMimeTypes == [.plainText, .plainTextUTF8])
        #expect(
            device.selections
                == [
                    RecordingDataTransferDeviceBinding.Selection(
                        sourceID: source.id,
                        serial: InputSerial(rawValue: 44)
                    )
                ]
        )
        #expect(manager.seatSnapshots.first?.selectionSourceID == source.id)
    }

    @Test
    func replacingSelectionSourceDestroysPreviousSource() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        let first = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 50)
        )
        let firstBinding = try #require(backend.sourceBinding(for: first.id))
        let second = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.uriList],
            serial: InputSerial(rawValue: 51)
        )

        #expect(firstBinding.destroyCount == 1)
        #expect(manager.sourceSnapshots.map(\.id) == [second.id])
        #expect(
            manager.drainDataTransferEvents()
                == [.clipboardSourceCancelled(ClipboardSourceIdentity(first.id))]
        )
        #expect(
            device.selections
                == [
                    RecordingDataTransferDeviceBinding.Selection(
                        sourceID: first.id,
                        serial: InputSerial(rawValue: 50)
                    ),
                    RecordingDataTransferDeviceBinding.Selection(
                        sourceID: second.id,
                        serial: InputSerial(rawValue: 51)
                    ),
                ]
        )
    }

    @Test
    func clearingSelectionSourceSetsNilSelectionAndDestroysCurrentSource() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 60)
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        try manager.clearSelectionSource(seatID: seat1, serial: InputSerial(rawValue: 61))

        #expect(sourceBinding.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
        #expect(manager.seatSnapshots.first?.selectionSourceID == nil)
        #expect(
            manager.drainDataTransferEvents()
                == [.clipboardSourceCancelled(ClipboardSourceIdentity(source.id))]
        )
        #expect(
            device.selections
                == [
                    RecordingDataTransferDeviceBinding.Selection(
                        sourceID: source.id,
                        serial: InputSerial(rawValue: 60)
                    ),
                    RecordingDataTransferDeviceBinding.Selection(
                        sourceID: nil,
                        serial: InputSerial(rawValue: 61)
                    ),
                ]
        )
    }

    @Test
    func sourceCancellationDestroysBindingAndPublishesCancellation() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 70)
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(.cancelled)

        #expect(sourceBinding.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
        #expect(
            manager.drainDataTransferEvents()
                == [.clipboardSourceCancelled(ClipboardSourceIdentity(source.id))]
        )
    }

    @Test
    func sourcePayloadSetRejectsEmptyPayloadDictionary() {
        #expect(throws: DataTransferError.emptyDataSource) {
            _ = try DataTransferSourcePayloadSet(data: [:])
        }
    }

    @Test
    func sourceSendForUnavailableMimeClosesDescriptorAndReportsMimeError() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 76)
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(.send(mimeType: MIMEType.uriList.rawValue, fd: 201))

        #expect(backend.closedDescriptors == [201])
        #expect(
            manager.pendingCallbackError
                == DataTransferCallbackFailure(
                    context: .dataSource(ClipboardSourceIdentity(source.id)),
                    error: .mimeTypeUnavailable(.uriList)
                )
        )
        #expect(
            throws: DataTransferCallbackFailure(
                context: .dataSource(ClipboardSourceIdentity(source.id)),
                error: .mimeTypeUnavailable(.uriList)
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }

    @Test
    func sourceSendWithInvalidMimeClosesDescriptorAndReportsMimeValidationError() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 77)
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(.send(mimeType: nil, fd: 202))

        #expect(backend.closedDescriptors == [202])
        #expect(
            manager.pendingCallbackError
                == DataTransferCallbackFailure(
                    context: .dataSource(ClipboardSourceIdentity(source.id)),
                    error: .invalidMIMEType("")
                )
        )
        #expect(
            throws: DataTransferCallbackFailure(
                context: .dataSource(ClipboardSourceIdentity(source.id)),
                error: .invalidMIMEType("")
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }

    @Test
    func sourceSendCloseFailureReportsCloseError() throws {
        let backend = RecordingDataTransferBackend()
        backend.failingCloseDescriptors[203] = 9
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 78)
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(.send(mimeType: MIMEType.uriList.rawValue, fd: 203))

        #expect(backend.closedDescriptors == [203])
        #expect(
            throws: DataTransferCallbackFailure(
                context: .dataSource(ClipboardSourceIdentity(source.id)),
                error: .closeFileDescriptor(
                    WaylandSystemErrno(unchecked: 9)
                )
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }

    @Test
    func settingSelectionSourceRejectsUnknownSeatAndSeatWithoutDataDevice() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)

        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            _ = try manager.setSelectionSource(
                seatID: seat1,
                mimeTypes: [.plainText],
                serial: InputSerial(rawValue: 80)
            )
        }

        manager.store.replaceState(
            try DataTransferState(
                seats: [
                    seat2: DataTransferSeatSnapshot(
                        seatID: seat2,
                        device: .unbound
                    )
                ]
            )
        )

        #expect(throws: DataTransferError.missingDataDevice(seat2)) {
            _ = try manager.setSelectionSource(
                seatID: seat2,
                mimeTypes: [.plainText],
                serial: InputSerial(rawValue: 81)
            )
        }
    }
}
