import Synchronization
import Testing

@testable import WaylandClient

@Suite
struct DisplayCoreSoftwarePresentationTests {
    @Test
    func reservationForClosedWindowReturnsClosed() throws {
        let core = DisplayCore(eventHub: DisplayEventHub())

        #expect(
            try core.reserveSoftwareFrameForRedraw(WindowID(rawValue: 42)) == .closed
        )
    }

    @Test
    func submissionForClosedWindowReturnsClosedWithoutDrawing() throws {
        let core = DisplayCore(eventHub: DisplayEventHub())
        let surfaceGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 1, height: 1),
            scale: .one
        )
        let reservation = SoftwareFrameReservation(
            reservationID: SoftwareFrameReservationToken(rawValue: 1),
            id: SoftwareFrameBufferID(rawValue: 1),
            width: 1,
            height: 1,
            stride: 4,
            geometry: SoftwareFrameGeometry(surface: surfaceGeometry)
        )
        let didDraw = Mutex(false)

        let outcome = try core.submitReservedSoftwareFrame(
            WindowID(rawValue: 42),
            reservation: reservation,
            submitConstraints: .default,
            metadata: .default,
            requestPresentationFeedback: true,
            damage: nil
        ) { _ in
            didDraw.withLock { $0 = true }
        }

        #expect(outcome == .closed)
        #expect(!didDraw.withLock { $0 })
    }
}
