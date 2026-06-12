extension SeatID: UInt32WaylandEntityID {}

extension InputSerial: UInt32WaylandEntityID {}

extension WindowID: UInt64WaylandEntityID {}

extension PopupID: UInt64WaylandEntityID {}

extension DataOfferID: UInt64WaylandEntityID {}

extension DataSourceID: UInt64WaylandEntityID {}

extension RelativePointerSubscriptionID: UInt64WaylandEntityID {}

extension InputSerialActionID: UInt64WaylandEntityID {}

extension ActivationRequestID: UInt64WaylandEntityID,
    CustomStringConvertible
{
    package var description: String {
        "activation-request-\(rawValue)"
    }
}

extension SurfacePresentationIdentity: UInt64WaylandEntityID {}

extension Window: Identifiable {}
extension RelativePointerSubscription: Identifiable {}
extension PointerConstraint: Identifiable {}

extension TextInputSession: Identifiable {
    public var id: SeatID {
        seatID
    }
}
