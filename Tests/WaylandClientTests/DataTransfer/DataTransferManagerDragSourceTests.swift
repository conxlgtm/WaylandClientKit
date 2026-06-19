// swiftlint:disable file_length

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
                        icon: nil,
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
                    .dragSourceFinished(
                        DragSourceFinishedEvent(sourceID: source.id, finalAction: .move)
                    ),
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
        binding.emit(.action(.copy))
        binding.emit(.dndDropPerformed)
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
    func finishedDragSourcePendingSendSurvivesCancellingClipboardSource() throws {
        let (manager, backend, dragSource) = try managerWithStartedDragSource()
        let dragBinding = try #require(backend.sourceBinding(for: dragSource.id))

        dragBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: 223))
        dragBinding.emit(.action(.copy))
        dragBinding.emit(.dndDropPerformed)
        dragBinding.emit(.dndFinished)
        _ = manager.drainDataTransferEvents()

        let clipboardSource = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: serial
        )
        let clipboardBinding = try #require(backend.sourceBinding(for: clipboardSource.id))

        clipboardBinding.emit(.cancelled)

        let request = try #require(manager.drainSourceSendRequests().first)
        #expect(request.source == .dragAndDrop(dragSource.id))
        #expect(request.mimeType == .plainText)
        #expect(backend.closedDescriptors.isEmpty)
        #expect(clipboardBinding.destroyCount == 1)
    }

    @Test
    func finishedDragSourcePendingSendSurvivesCancellingAnotherDragSource() throws {
        let (manager, backend, firstSource) = try managerWithStartedDragSource()
        let firstBinding = try #require(backend.sourceBinding(for: firstSource.id))

        firstBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: 224))
        firstBinding.emit(.action(.copy))
        firstBinding.emit(.dndDropPerformed)
        firstBinding.emit(.dndFinished)
        _ = manager.drainDataTransferEvents()

        let secondSource = try manager.startDrag(try startDragRequest(actions: [.copy]))
        let secondBinding = try #require(backend.sourceBinding(for: secondSource.id))

        try manager.cancelDragSource(id: secondSource.id)

        let request = try #require(manager.drainSourceSendRequests().first)
        #expect(request.source == .dragAndDrop(firstSource.id))
        #expect(request.mimeType == .plainText)
        #expect(backend.closedDescriptors.isEmpty)
        #expect(secondBinding.destroyCount == 1)
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
                == [
                    .sourceSendRequested(
                        DataTransferSourceTransferEvent(
                            source: DragSourceIdentity(source.id),
                            mimeType: .plainText
                        )
                    ),
                    .dragSourceCancelled(DragSourceIdentity(source.id)),
                ]
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

    private func startDragRequest(
        actions: DragActionSet,
        icon: DragIcon = .none
    ) throws -> DataTransferStartDragRequest {
        try DataTransferStartDragRequest(
            seatID: seatID,
            payloads: dragPayloads(),
            actions: actions,
            serial: serial,
            origin: origin,
            icon: icon
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
struct DataTransferManagerDragSourceCallbackTests {  // swiftlint:disable:this type_body_length
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
    func dragSourceTargetEmptyPublishesNoAcceptedMIME() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.target(""))

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
    func dragSourceActionRejectsKnownActionOutsideOfferedSet() throws {
        let (manager, backend, source) = try managerWithStartedDragSource(actions: [.move])
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.action(.copy))

        #expect(
            throws: DataTransferCallbackFailure(
                context: .dragSource(DragSourceIdentity(source.id)),
                error: .unsupportedDragAction(action: .copy, available: [.move])
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        #expect(manager.drainDataTransferEvents().isEmpty)
    }

    @Test
    func dragSourceActionNoneIsAccepted() throws {
        let (manager, backend, source) = try managerWithStartedDragSource(actions: [.move])
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.action(.none))

        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragSourceActionChanged(
                        DragSourceActionEvent(sourceID: source.id, action: .none)
                    )
                ]
        )
        try manager.throwPendingCallbackErrorIfAny()
    }

    @Test
    func dragSourceActionAskRequiresAskOffered() throws {
        let (manager, backend, source) = try managerWithStartedDragSource(actions: [.copy])
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.action(.ask))

        #expect(
            throws: DataTransferCallbackFailure(
                context: .dragSource(DragSourceIdentity(source.id)),
                error: .unsupportedDragAction(action: .ask, available: [.copy])
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        #expect(manager.drainDataTransferEvents().isEmpty)
    }

    @Test
    func dragSourceFinishedIncludesLatestSelectedAction() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.action(.copy))
        binding.emit(.action(.move))
        binding.emit(.dndDropPerformed)
        binding.emit(.dndFinished)

        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragSourceActionChanged(
                        DragSourceActionEvent(sourceID: source.id, action: .copy)
                    ),
                    .dragSourceActionChanged(
                        DragSourceActionEvent(sourceID: source.id, action: .move)
                    ),
                    .dragSourceDropPerformed(DragSourceIdentity(source.id)),
                    .dragSourceFinished(
                        DragSourceFinishedEvent(sourceID: source.id, finalAction: .move)
                    ),
                ]
        )
        try manager.throwPendingCallbackErrorIfAny()
    }

    @Test
    func dragSourceAskFinalActionBeforeFinishedWins() throws {
        let (manager, backend, source) = try managerWithStartedDragSource(
            actions: [.copy, .move, .ask]
        )
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.action(.ask))
        binding.emit(.dndDropPerformed)
        binding.emit(.action(.copy))
        binding.emit(.dndFinished)

        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragSourceActionChanged(
                        DragSourceActionEvent(sourceID: source.id, action: .ask)
                    ),
                    .dragSourceDropPerformed(DragSourceIdentity(source.id)),
                    .dragSourceActionChanged(
                        DragSourceActionEvent(sourceID: source.id, action: .copy)
                    ),
                    .dragSourceFinished(
                        DragSourceFinishedEvent(sourceID: source.id, finalAction: .copy)
                    ),
                ]
        )
        try manager.throwPendingCallbackErrorIfAny()
    }

    @Test
    func dragSourceFinishedWithoutSelectedActionRecordsCallbackFailure() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.dndDropPerformed)
        binding.emit(.dndFinished)

        #expect(
            throws: DataTransferCallbackFailure(
                context: .dragSource(DragSourceIdentity(source.id)),
                error: .invalidSourceEvent(.dndFinished)
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        #expect(
            manager.drainDataTransferEvents()
                == [.dragSourceDropPerformed(DragSourceIdentity(source.id))]
        )
        #expect(backend.sourceBinding(for: source.id)?.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
    }

    @Test
    func dragSourceFinishedBeforeDropRecordsCallbackFailure() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.action(.copy))
        binding.emit(.dndFinished)

        #expect(
            throws: DataTransferCallbackFailure(
                context: .dragSource(DragSourceIdentity(source.id)),
                error: .invalidSourceEvent(.dndFinished)
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragSourceActionChanged(
                        DragSourceActionEvent(sourceID: source.id, action: .copy)
                    )
                ]
        )
        #expect(backend.sourceBinding(for: source.id)?.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
    }

    @Test
    func dragSourceFinishedAfterAskWithoutFinalActionRecordsCallbackFailure() throws {
        let (manager, backend, source) = try managerWithStartedDragSource(
            actions: [.copy, .ask]
        )
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.action(.ask))
        binding.emit(.dndDropPerformed)
        binding.emit(.dndFinished)

        #expect(
            throws: DataTransferCallbackFailure(
                context: .dragSource(DragSourceIdentity(source.id)),
                error: .invalidSourceEvent(.dndFinished)
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragSourceActionChanged(
                        DragSourceActionEvent(sourceID: source.id, action: .ask)
                    ),
                    .dragSourceDropPerformed(DragSourceIdentity(source.id)),
                ]
        )
        #expect(binding.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
    }

    @Test
    func dragSourceFinishedAfterNoneRecordsCallbackFailure() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.action(.none))
        binding.emit(.dndDropPerformed)
        binding.emit(.dndFinished)

        #expect(
            throws: DataTransferCallbackFailure(
                context: .dragSource(DragSourceIdentity(source.id)),
                error: .invalidSourceEvent(.dndFinished)
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragSourceActionChanged(
                        DragSourceActionEvent(sourceID: source.id, action: .none)
                    ),
                    .dragSourceDropPerformed(DragSourceIdentity(source.id)),
                ]
        )
        #expect(binding.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
    }

    @Test
    func unknownFinalDragSourceActionPreservesRawValue() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.action(RawDataDeviceDNDAction(rawValue: 8)))
        binding.emit(.dndDropPerformed)
        binding.emit(.dndFinished)

        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragSourceActionChanged(
                        DragSourceActionEvent(
                            sourceID: source.id,
                            action: .unknown(rawValue: 8)
                        )
                    ),
                    .dragSourceDropPerformed(DragSourceIdentity(source.id)),
                    .dragSourceFinished(
                        DragSourceFinishedEvent(
                            sourceID: source.id,
                            finalAction: .unknown(rawValue: 8)
                        )
                    ),
                ]
        )
        try manager.throwPendingCallbackErrorIfAny()
    }

    @Test
    func lateDragSourceCallbackAfterFinishKeepsDragSourceContext() throws {
        let (manager, backend, source) = try managerWithStartedDragSource()
        let binding = try #require(backend.sourceBinding(for: source.id))

        binding.emit(.action(.copy))
        binding.emit(.dndDropPerformed)
        binding.emit(.dndFinished)
        _ = manager.drainDataTransferEvents()

        #expect(manager.sourceSnapshots.isEmpty)
        binding.emit(.target(MIMEType.plainText.rawValue))

        #expect(
            throws: DataTransferCallbackFailure(
                context: .dragSource(DragSourceIdentity(source.id)),
                error: .unknownDragSourceIdentity(DragSourceIdentity(source.id))
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        #expect(manager.drainDataTransferEvents().isEmpty)
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
        try managerWithStartedDragSource(actions: [.copy, .move])
    }

    private func managerWithStartedDragSource(
        actions: DragActionSet
    ) throws -> (
        manager: DataTransferManager,
        backend: RecordingDataTransferBackend,
        source: DataSourceSnapshot
    ) {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let source = try manager.startDrag(
            try startDragRequest(actions: actions)
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
