import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferDragRawTests {
    @Test
    func dragLocationPreservesRawFixedCoordinates() {
        #expect(
            DragLocation(
                x: WaylandFixed(rawValue: 384),
                y: WaylandFixed(rawValue: -128)
            )
                == DragLocation(x: 1.5, y: -0.5)
        )
    }

    @Test
    func dragEnterTransitionPreservesRawEnterFacts() {
        let enter = unsafe RawDataDeviceEnter(
            serial: 55,
            surface: nil,
            x: WaylandFixed(rawValue: 256),
            y: WaylandFixed(rawValue: 512),
            offer: nil,
            surfaceID: nil
        )

        #expect(
            DataTransferDragEnterTransition(
                enter,
                seatID: SeatID(rawValue: 3),
                offerID: DataOfferID(rawValue: 7),
                target: .focusless
            )
                == DataTransferDragEnterTransition(
                    seatID: SeatID(rawValue: 3),
                    offerID: DataOfferID(rawValue: 7),
                    serial: InputSerial(rawValue: 55),
                    location: DragLocation(x: 1, y: 2),
                    target: .focusless
                )
        )
    }
}
