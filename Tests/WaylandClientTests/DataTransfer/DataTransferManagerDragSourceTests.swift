import Foundation
import Testing

@testable import WaylandClient
@testable import WaylandRaw

@Suite
struct DataTransferManagerDragSourceTests {
    private let seatID = SeatID(rawValue: 1)
    private let origin = RecordingDataTransferDragOriginBinding(id: 0x57)
    private let serial = InputSerial(rawValue: 44)

    @Test
    func startDragCreatesSourceAndSendsStartDragRequest() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])

        let source = try manager.startDrag(
            try startDragRequest(actions: [.copy, .move])
        )

        let binding = try #require(backend.sourceBinding(for: source.id))
        let device = try #require(backend.binding(for: seatID))

        #expect(source.seatID == seatID)
        #expect(source.mimeTypes == [.plainText, .uriList])
        #expect(source.role.seatID == seatID)
        #expect(source.role.dragActions == [.copy, .move])
        #expect(binding.offeredMimeTypes == [.plainText, .uriList])
        #expect(binding.actionRequests == [[.copy, .move]])
        #expect(
            device.dragStarts
                == [
                    .init(
                        sourceID: source.id,
                        originID: origin.id,
                        icon: .none,
                        serial: serial
                    )
                ]
        )
    }

    @Test
    func startDragRejectsVersionBelowThreeBeforeCreatingSource() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let device = try #require(backend.binding(for: seatID))
        device.protocolVersion = 2

        #expect(
            throws: DataTransferError.dragSourceActionNegotiationUnavailable(
                DragSourceIdentity(DataSourceID(rawValue: 1))
            )
        ) {
            _ = try manager.startDrag(try startDragRequest(actions: [.copy]))
        }
        #expect(backend.sourceBinding(for: DataSourceID(rawValue: 1)) == nil)
        #expect(device.dragStarts.isEmpty)
    }

    @Test
    func startDragRejectsSourceVersionBelowThreeAndDestroysSource() throws {
        let backend = RecordingDataTransferBackend()
        backend.sourceBindingProtocolVersion = 2
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let device = try #require(backend.binding(for: seatID))

        #expect(
            throws: DataTransferError.dragSourceActionNegotiationUnavailable(
                DragSourceIdentity(DataSourceID(rawValue: 1))
            )
        ) {
            _ = try manager.startDrag(try startDragRequest(actions: [.copy]))
        }

        let sourceBinding = try #require(
            backend.sourceBinding(for: DataSourceID(rawValue: 1))
        )
        #expect(sourceBinding.destroyCount == 1)
        #expect(sourceBinding.offeredMimeTypes.isEmpty)
        #expect(sourceBinding.actionRequests.isEmpty)
        #expect(manager.sourceSnapshots.isEmpty)
        #expect(device.dragStarts.isEmpty)
    }

    @Test
    func dragSourceLifecycleCallbacksPublishEventsAndFinishDestroysSource() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.target(MIMEType.plainText.rawValue))
        binding.emit(.action(.move))
        binding.emit(.dndDropPerformed)
        binding.emit(.dndFinished)

        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragSourceTargetChanged(
                        DragSourceTargetEvent(sourceID: source.id, mimeType: .plainText)
                    ),
                    .dragSourceActionChanged(
                        DragSourceActionEvent(sourceID: source.id, action: .move)
                    ),
                    .dragSourceDropPerformed(DragSourceIdentity(source.id)),
                    .dragSourceFinished(DragSourceIdentity(source.id)),
                ]
        )
        #expect(binding.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
    }

    @Test
    func dragSourceFinishedPreservesQueuedSendRequest() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: 223))
        binding.emit(.dndFinished)

        let request = try #require(manager.drainSourceSendRequests().first)
        #expect(request.source == .dragAndDrop(source.id))
        #expect(request.mimeType == .plainText)
        #expect(request.data == Data("drag source".utf8))
        #expect(backend.closedDescriptors.isEmpty)
        #expect(binding.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
    }

    @Test
    func dragSourceSendQueuesDragScopedWriteRequest() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.send(mimeType: MIMEType.uriList.rawValue, fd: 220))

        let request = try #require(manager.drainSourceSendRequests().first)
        #expect(request.source == .dragAndDrop(source.id))
        #expect(request.mimeType == .uriList)
        #expect(request.data == Data("file:///tmp/source".utf8))
        #expect(backend.closedDescriptors.isEmpty)
    }

    @Test
    func dragSourceCancelledPublishesDragCancellationAndCancelsPendingWrites() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: 221))
        binding.emit(.cancelled)

        #expect(
            manager.drainDataTransferEvents()
                == [.dragSourceCancelled(DragSourceIdentity(source.id))]
        )
        #expect(binding.destroyCount == 1)
        #expect(backend.closedDescriptors == [221])
        #expect(manager.sourceSnapshots.isEmpty)
    }

    @Test
    func cancelDragSourceDestroysSourceAndPublishesCancellation() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        try manager.cancelDragSource(id: source.id)

        #expect(
            manager.drainDataTransferEvents()
                == [.dragSourceCancelled(DragSourceIdentity(source.id))]
        )
        #expect(binding.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
    }

    @Test
    func cancelDragSourceRejectsSelectionSource() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: serial
        )
        let binding = try #require(backend.sourceBinding(for: source.id))

        #expect(
            throws: DataTransferError.unknownDragSourceIdentity(
                DragSourceIdentity(source.id)
            )
        ) {
            try manager.cancelDragSource(id: source.id)
        }
        #expect(binding.destroyCount == 0)
        #expect(manager.sourceSnapshots == [source])
    }

    private func managerWithStartedDragSource() throws -> (
        manager: DataTransferManager,
        backend: RecordingDataTransferBackend,
        source: DataSourceSnapshot
    ) {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let source = try manager.startDrag(
            try startDragRequest(actions: [.copy, .move])
        )
        return (manager, backend, source)
    }

    private func startDragRequest(actions: DragActionSet) throws -> DataTransferStartDragRequest {
        try DataTransferStartDragRequest(
            seatID: seatID,
            payloads: dragPayloads(),
            actions: actions,
            serial: serial,
            origin: origin,
            icon: .none
        )
    }

    private func dragPayloads() throws -> DataTransferSourcePayloadSet {
        try DataTransferSourcePayloadSet(
            data: [
                .plainText: Data("drag source".utf8),
                .uriList: Data("file:///tmp/source".utf8),
            ]
        )
    }
}

@Suite
struct DataTransferManagerDragSourceCallbackTests {
    private let seatID = SeatID(rawValue: 1)
    private let origin = RecordingDataTransferDragOriginBinding(id: 0x57)
    private let serial = InputSerial(rawValue: 44)

    @Test
    func dragSourceTargetNilPublishesNoAcceptedMIME() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.target(nil))

        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragSourceTargetChanged(
                        DragSourceTargetEvent(sourceID: source.id, mimeType: nil)
                    )
                ]
        )
        try manager.throwPendingCallbackErrorIfAny()
    }

    @Test
    func dragSourceTargetRejectsMalformedMIMEWithDragSourceContext() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.target(" text/plain "))

        #expect(
            throws: DataTransferCallbackFailure(
                context: .dragSource(DragSourceIdentity(source.id)),
                error: .invalidMIMEType(" text/plain ")
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        #expect(manager.drainDataTransferEvents().isEmpty)
    }

    @Test
    func dragSourceTargetRejectsUnavailableMIMEWithDragSourceContext() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))
        let unavailable = try MIMEType("application/json")

        binding.emit(.target(unavailable.rawValue))

        #expect(
            throws: DataTransferCallbackFailure(
                context: .dragSource(DragSourceIdentity(source.id)),
                error: .mimeTypeUnavailable(unavailable)
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        #expect(manager.drainDataTransferEvents().isEmpty)
    }

    @Test
    func unknownDragSourceActionPublishesUnknownRawValue() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.action(RawDataDeviceDNDAction(rawValue: 8)))

        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragSourceActionChanged(
                        DragSourceActionEvent(
                            sourceID: source.id,
                            action: .unknown(rawValue: 8)
                        )
                    )
                ]
        )
        try manager.throwPendingCallbackErrorIfAny()
    }

    @Test
    func selectionSourceTargetCallbackRecordsInvalidSourceEvent() throws {
        try expectSelectionSourceEventRejected(
            .target(MIMEType.plainText.rawValue),
            event: .target
        )
    }

    @Test
    func selectionSourceActionCallbackRecordsInvalidSourceEvent() throws {
        try expectSelectionSourceEventRejected(.action(.copy), event: .action)
    }

    @Test
    func selectionSourceDropPerformedRecordsInvalidSourceEvent() throws {
        try expectSelectionSourceEventRejected(.dndDropPerformed, event: .dndDropPerformed)
    }

    @Test
    func selectionSourceDndFinishedRecordsInvalidSourceEvent() throws {
        try expectSelectionSourceEventRejected(.dndFinished, event: .dndFinished)
    }

    private func expectSelectionSourceEventRejected(
        _ event: RawDataSourceEvent,
        event eventKind: DataSourceCallbackEventKind
    ) throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: serial
        )
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(event)

        #expect(
            throws: DataTransferCallbackFailure(
                context: .dataSource(ClipboardSourceIdentity(source.id)),
                error: .invalidSourceEvent(eventKind)
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        #expect(manager.drainDataTransferEvents().isEmpty)
        #expect(binding.destroyCount == 0)
    }

    private func managerWithStartedDragSource() throws -> (
        manager: DataTransferManager,
        backend: RecordingDataTransferBackend,
        source: DataSourceSnapshot
    ) {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let source = try manager.startDrag(
            try startDragRequest(actions: [.copy, .move])
        )
        return (manager, backend, source)
    }

    private func startDragRequest(actions: DragActionSet) throws -> DataTransferStartDragRequest {
        try DataTransferStartDragRequest(
            seatID: seatID,
            payloads: dragPayloads(),
            actions: actions,
            serial: serial,
            origin: origin,
            icon: .none
        )
    }

    private func dragPayloads() throws -> DataTransferSourcePayloadSet {
        try DataTransferSourcePayloadSet(
            data: [
                .plainText: Data("drag source".utf8),
                .uriList: Data("file:///tmp/source".utf8),
            ]
        )
    }
}
