import Foundation
import Testing

@testable import WaylandClient

@Suite
struct DataTransferManagerDragIconTests {
    private let seatID = SeatID(rawValue: 1)
    private let origin = RecordingDataTransferDragOriginBinding(id: 0x57)
    private let serial = InputSerial(rawValue: 44)

    @Test
    func startDragKeepsPreparedIconUntilSourceIsDestroyed() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let icon = try dragIcon()

        let source = try manager.startDrag(
            try startDragRequest(actions: [.copy, .move], icon: icon)
        )

        let binding = try #require(backend.sourceBinding(for: source.id))
        let iconBinding = try #require(
            binding.dragIcon as? RecordingDataTransferDragIconBinding
        )
        let device = try #require(backend.binding(for: seatID))

        #expect(backend.preparedDragIcons == [icon])
        #expect(device.dragStarts.map(\.icon) == [icon])

        binding.emit(.action(.copy))
        binding.emit(.dndDropPerformed)
        binding.emit(.dndFinished)

        #expect(iconBinding.destroyCount == 1)
        #expect(binding.dragIcon == nil)
    }

    @Test
    func startDragIconPreparationFailureDestroysSource() throws {
        let icon = try dragIcon()
        let backend = RecordingDataTransferBackend()
        backend.failingDragIcon = icon
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])

        #expect(throws: DataTransferError.cancelled) {
            _ = try manager.startDrag(try startDragRequest(actions: [.copy], icon: icon))
        }

        let sourceBinding = try #require(
            backend.sourceBinding(for: DataSourceID(rawValue: 1))
        )
        #expect(sourceBinding.destroyCount == 1)
        #expect(sourceBinding.dragIcon == nil)
        #expect(backend.preparedDragIcons == [icon])
    }

    @Test
    func dragIconImageRejectsWrongPixelCount() throws {
        let size = try PositivePixelSize(width: 2, height: 2)

        #expect(
            throws: DataTransferError.invalidDragIconPixelCount(expected: 4, actual: 3)
        ) {
            _ = try DragIconImage(size: size, pixels: [0, 1, 2])
        }
    }

    private func startDragRequest(
        actions: DragActionSet,
        icon: DragIcon = .none
    ) throws -> DataTransferStartDragRequest {
        try DataTransferStartDragRequest(
            seatID: seatID,
            payloads: dragPayloads(),
            actions: actions,
            serial: serial,
            origin: origin,
            icon: icon
        )
    }

    private func dragIcon() throws -> DragIcon {
        .xrgb8888(
            try DragIconImage(
                size: PositivePixelSize(width: 2, height: 1),
                pixels: [0x00FF_0000, 0x0000_FF00]
            )
        )
    }

    private func dragPayloads() throws -> DataTransferSourcePayloadSet {
        try DataTransferSourcePayloadSet(
            data: [
                .plainText: Data("drag source".utf8),
                .uriList: Data("file:///tmp/source".utf8),
            ]
        )
    }
}
