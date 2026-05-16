import Testing

@testable import WaylandClient

@Suite
struct DataTransferEffectEventTests {
    private let seatID = SeatID(rawValue: 4)
    private let offerID = DataOfferID(rawValue: 8)
    private let sourceID = DataSourceID(rawValue: 12)

    @Test
    func selectionPublishEffectsMapToEvents() {
        #expect(
            DataTransferEffect.publishSelectionChanged(seatID: seatID, offerID: offerID)
                .publishedEvent
                == .clipboardSelectionChanged(
                    ClipboardSelectionEvent(seatID: seatID, offerID: offerID)
                )
        )
        #expect(
            DataTransferEffect.publishSourceCancelled(sourceID).publishedEvent
                == .clipboardSourceCancelled(sourceID.clipboardIdentity)
        )
    }

    @Test
    func dragOfferPublishEffectsMapToEvents() {
        let location = DragLocation(x: 1.5, y: 2.5)
        let enter = DataTransferDragEnterTransition(
            seatID: seatID,
            offerID: offerID,
            serial: 99,
            location: location,
            target: .focusless
        )

        #expect(
            DataTransferEffect.publishDragEntered(enter).publishedEvent
                == .dragEntered(
                    DragEnterEvent(
                        seatID: seatID,
                        offerID: offerID,
                        serial: 99,
                        location: location,
                        target: .focusless
                    )
                )
        )
        #expect(
            DataTransferEffect.publishDragMotion(
                seatID: seatID,
                offerID: offerID,
                time: 24,
                location: location
            )
            .publishedEvent
                == .dragMotion(
                    DragMotionEvent(
                        seatID: seatID,
                        offerID: offerID,
                        time: 24,
                        location: location
                    )
                )
        )
        #expect(
            DataTransferEffect.publishDragLeft(seatID: seatID, offerID: offerID)
                .publishedEvent
                == .dragLeft(DragLeaveEvent(seatID: seatID, offerID: offerID))
        )
        #expect(
            DataTransferEffect.publishDragDropped(seatID: seatID, offerID: offerID)
                .publishedEvent
                == .dragDropped(DragDropEvent(seatID: seatID, offerID: offerID))
        )
        #expect(
            DataTransferEffect.publishDragOfferChanged(seatID: seatID, offerID: offerID)
                .publishedEvent
                == .dragOfferChanged(DragOfferChangedEvent(seatID: seatID, offerID: offerID))
        )
    }

    @Test
    func dragSourcePublishEffectsMapToEvents() {
        #expect(
            DataTransferEffect.publishDragSourceCancelled(sourceID).publishedEvent
                == .dragSourceCancelled(sourceID.dragIdentity)
        )
        #expect(
            DataTransferEffect.publishDragSourceTargetChanged(
                id: sourceID,
                mimeType: .plainText
            )
            .publishedEvent
                == .dragSourceTargetChanged(
                    DragSourceTargetEvent(sourceID: sourceID, mimeType: .plainText)
                )
        )
        #expect(
            DataTransferEffect.publishDragSourceActionChanged(
                id: sourceID,
                action: .copy
            )
            .publishedEvent
                == .dragSourceActionChanged(
                    DragSourceActionEvent(sourceID: sourceID, action: .copy)
                )
        )
        #expect(
            DataTransferEffect.publishDragSourceDropPerformed(sourceID).publishedEvent
                == .dragSourceDropPerformed(sourceID.dragIdentity)
        )
        #expect(
            DataTransferEffect.publishDragSourceFinished(id: sourceID, finalAction: .copy)
                .publishedEvent
                == .dragSourceFinished(
                    DragSourceFinishedEvent(sourceID: sourceID, finalAction: .copy)
                )
        )
    }

    @Test
    func sideEffectsDoNotPublishEvents() {
        #expect(DataTransferEffect.bindDataDevice(seatID).publishedEvent == nil)
        #expect(DataTransferEffect.releaseDataDevice(seatID).publishedEvent == nil)
        #expect(DataTransferEffect.destroyOffer(offerID).publishedEvent == nil)
        #expect(DataTransferEffect.destroySource(sourceID).publishedEvent == nil)
        #expect(DataTransferEffect.cancelSource(sourceID).publishedEvent == nil)
    }

    @Test
    func sideEffectsMapToRuntimeSideEffects() {
        #expect(
            DataTransferEffect.bindDataDevice(seatID).runtimeSideEffect
                == .bindDataDevice(seatID)
        )
        #expect(
            DataTransferEffect.releaseDataDevice(seatID).runtimeSideEffect
                == .releaseDataDevice(seatID)
        )
        #expect(
            DataTransferEffect.destroyOffer(offerID).runtimeSideEffect
                == .destroyOffer(offerID)
        )
        #expect(
            DataTransferEffect.destroySource(sourceID).runtimeSideEffect
                == .destroySource(sourceID)
        )
        #expect(
            DataTransferEffect.cancelSource(sourceID).runtimeSideEffect
                == .cancelSource(sourceID)
        )
    }

    @Test
    func publishEffectsDoNotMapToRuntimeSideEffects() {
        #expect(
            DataTransferEffect.publishSelectionChanged(
                seatID: seatID,
                offerID: offerID
            )
            .runtimeSideEffect == nil
        )
        #expect(DataTransferEffect.publishSourceCancelled(sourceID).runtimeSideEffect == nil)
        #expect(
            DataTransferEffect.publishDragDropped(
                seatID: seatID,
                offerID: offerID
            )
            .runtimeSideEffect == nil
        )
        #expect(
            DataTransferEffect.publishDragSourceCancelled(sourceID).runtimeSideEffect == nil
        )
    }
}
