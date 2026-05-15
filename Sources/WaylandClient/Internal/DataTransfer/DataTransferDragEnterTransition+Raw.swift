import WaylandRaw

extension DataTransferDragEnterTransition {
    package init(
        _ enter: RawDataDeviceEnter,
        seatID eventSeatID: SeatID,
        offerID eventOfferID: DataOfferID,
        target eventTarget: InputEventTarget
    ) {
        self.init(
            seatID: eventSeatID,
            offerID: eventOfferID,
            serial: InputSerial(rawValue: enter.serial),
            location: DragLocation(x: enter.x, y: enter.y),
            target: eventTarget
        )
    }
}
