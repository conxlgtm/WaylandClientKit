extension Window: Identifiable {}
extension RelativePointerSubscription: Identifiable {}
extension PointerConstraint: Identifiable {}

extension TextInputSession: Identifiable {
    public var id: SeatID {
        seatID
    }
}
