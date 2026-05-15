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
    }

    @Test
    func sourceIDsProduceRoleIdentities() {
        let sourceID = DataSourceID(rawValue: 64)

        #expect(sourceID.clipboardIdentity == ClipboardSourceIdentity(sourceID))
        #expect(sourceID.primarySelectionIdentity == PrimarySelectionSourceIdentity(sourceID))
        #expect(sourceID.dragIdentity == DragSourceIdentity(sourceID))
    }
}
