package struct DataTransferStartDragRequest {
    package let seatID: SeatID
    package let payloads: DataTransferSourcePayloadSet
    package let actions: DragActionSet
    package let serial: InputSerial
    package let origin: any DataTransferDragOriginBinding
    package let icon: DragIcon
    package let beforeStartDrag: ((any DataTransferSourceBinding) throws -> Void)?

    package init(
        seatID requestSeatID: SeatID,
        payloads requestPayloads: DataTransferSourcePayloadSet,
        actions requestActions: DragActionSet,
        serial requestSerial: InputSerial,
        origin requestOrigin: any DataTransferDragOriginBinding,
        icon requestIcon: DragIcon,
        beforeStartDrag requestBeforeStartDrag: (
            (any DataTransferSourceBinding) throws -> Void
        )? = nil
    ) {
        seatID = requestSeatID
        payloads = requestPayloads
        actions = requestActions
        serial = requestSerial
        origin = requestOrigin
        icon = requestIcon
        beforeStartDrag = requestBeforeStartDrag
    }
}
