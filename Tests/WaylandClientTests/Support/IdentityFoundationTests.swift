import Testing

@testable import WaylandClient

@Suite
struct IdentityFoundationTests {
    @Test
    func idGeneratorProducesDeterministicNonZeroIDs() {
        var generator = IDGenerator<WindowID>()

        #expect(generator.next() == WindowID(rawValue: 1))
        #expect(generator.next() == WindowID(rawValue: 2))
    }

    @Test
    func idGeneratorCanStartAtExplicitNonZeroValue() {
        var generator = IDGenerator<DataOfferID>(startingAt: 42)

        #expect(generator.next() == DataOfferID(rawValue: 42))
        #expect(generator.next() == DataOfferID(rawValue: 43))
    }

    @Test
    func descriptionsStayDomainPrefixed() {
        #expect(WindowID(rawValue: 7).description == "window-7")
        #expect(PopupID(rawValue: 8).description == "popup-8")
        #expect(DataOfferID(rawValue: 9).description == "data-offer-9")
        #expect(DataSourceID(rawValue: 10).description == "data-source-10")
        #expect(RelativePointerSubscriptionID(rawValue: 11).description == "relative-pointer-11")
        #expect(
            PointerConstraintID(rawValue: 12, kind: .locked).description
                == "locked-pointer-12"
        )
    }

    @Test
    func projectionIdentityDescriptionsUsePublicDomainPrefixes() {
        let offerID = DataOfferID(rawValue: 3)
        let sourceID = DataSourceID(rawValue: 4)

        #expect(ClipboardOfferIdentity(offerID).description == "clipboard-offer-3")
        #expect(PrimarySelectionOfferIdentity(offerID).description == "primary-selection-offer-3")
        #expect(DragOfferIdentity(offerID).description == "drag-offer-3")
        #expect(ClipboardSourceIdentity(sourceID).description == "clipboard-source-4")
        #expect(
            PrimarySelectionSourceIdentity(sourceID).description
                == "primary-selection-source-4"
        )
        #expect(DragSourceIdentity(sourceID).description == "drag-source-4")
    }

    @Test
    func displayOwnedIdentityDistinguishesSameRawIDAcrossDisplays() {
        final class DisplayToken {}

        let firstDisplayToken = DisplayToken()
        let secondDisplayToken = DisplayToken()
        let firstDisplay = ObjectIdentifier(firstDisplayToken)
        let secondDisplay = ObjectIdentifier(secondDisplayToken)
        let first = DisplayOwnedIdentity(
            id: WindowID(rawValue: 1),
            displayIdentity: firstDisplay
        )
        let second = DisplayOwnedIdentity(
            id: WindowID(rawValue: 1),
            displayIdentity: secondDisplay
        )

        #expect(first != second)
        #expect(first.isOwned(byDisplayIdentity: firstDisplay))
        #expect(!first.isOwned(byDisplayIdentity: secondDisplay))
    }
}
