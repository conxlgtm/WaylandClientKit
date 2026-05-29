extension SeatID: UInt32WaylandEntityID, PrefixedIdentityDescription {
    package static let descriptionPrefix = "seat"
}

extension InputSerial: UInt32WaylandEntityID, PrefixedIdentityDescription {
    package static let descriptionPrefix = "serial"
}

extension WindowID: UInt64WaylandEntityID, PrefixedIdentityDescription {
    package static let descriptionPrefix = "window"
}

extension PopupID: UInt64WaylandEntityID, PrefixedIdentityDescription {
    package static let descriptionPrefix = "popup"
}

extension DataOfferID: UInt64WaylandEntityID, PrefixedIdentityDescription {
    package static let descriptionPrefix = "data-offer"
}

extension DataSourceID: UInt64WaylandEntityID, PrefixedIdentityDescription {
    package static let descriptionPrefix = "data-source"
}

extension RelativePointerSubscriptionID: UInt64WaylandEntityID,
    PrefixedIdentityDescription
{
    package static let descriptionPrefix = "relative-pointer"
}

extension ActivationRequestID: UInt64WaylandEntityID,
    PrefixedIdentityDescription,
    CustomStringConvertible
{
    package static let descriptionPrefix = "activation-request"

    package var description: String {
        "\(Self.descriptionPrefix)-\(rawValue)"
    }
}

extension SurfacePresentationIdentity: UInt64WaylandEntityID,
    PrefixedIdentityDescription
{
    package static let descriptionPrefix = "presentation"
}

extension Window: Identifiable {}
extension RelativePointerSubscription: Identifiable {}
extension PointerConstraint: Identifiable {}

extension TextInputSession: Identifiable {
    public var id: SeatID {
        seatID
    }
}
