import Testing

@testable import WaylandClient

@Suite
struct DataTransferIdentityTests {
    @Test
    func offerIDsProduceRoleIdentities() {
        let offerID = DataOfferID(rawValue: 42)

        #expect(offerID.clipboardIdentity == ClipboardOfferIdentity(offerID))
        #expect(offerID.primarySelectionIdentity == PrimarySelectionOfferIdentity(offerID))
        #expect(offerID.dragIdentity == DragOfferIdentity(offerID))
        #expect(DataOfferID(offerID.clipboardIdentity) == offerID)
        #expect(DataOfferID(offerID.primarySelectionIdentity) == offerID)
        #expect(DataOfferID(offerID.dragIdentity) == offerID)
    }

    @Test
    func sourceIDsProduceRoleIdentities() {
        let sourceID = DataSourceID(rawValue: 64)

        #expect(sourceID.clipboardIdentity == ClipboardSourceIdentity(sourceID))
        #expect(sourceID.primarySelectionIdentity == PrimarySelectionSourceIdentity(sourceID))
        #expect(sourceID.dragIdentity == DragSourceIdentity(sourceID))
        #expect(DataSourceID(sourceID.clipboardIdentity) == sourceID)
        #expect(DataSourceID(sourceID.primarySelectionIdentity) == sourceID)
        #expect(DataSourceID(sourceID.dragIdentity) == sourceID)
    }

    @Test
    func cancellationEventsExposeWriteSources() {
        let sourceID = DataSourceID(rawValue: 99)
        let clipboardCancellation =
            DataTransferEvent.clipboardSourceCancelled(sourceID.clipboardIdentity)
        let primarySelectionCancellation =
            DataTransferEvent.primarySelectionSourceCancelled(
                sourceID.primarySelectionIdentity
            )
        let dragCancellation = DataTransferEvent.dragSourceCancelled(sourceID.dragIdentity)

        #expect(clipboardCancellation.cancelledWriteSource == .clipboard(sourceID))
        #expect(primarySelectionCancellation.cancelledWriteSource == .primarySelection(sourceID))
        #expect(dragCancellation.cancelledWriteSource == .dragAndDrop(sourceID))
    }

    @Test
    func nonCancellationEventsDoNotExposeWriteSources() {
        let selectionEvent = ClipboardSelectionEvent(
            seatID: SeatID(rawValue: 1),
            offerID: nil
        )
        let event = DataTransferEvent.clipboardSelectionChanged(selectionEvent)

        #expect(event.cancelledWriteSource == nil)
    }
}
