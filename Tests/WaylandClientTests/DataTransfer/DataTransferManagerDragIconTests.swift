#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Foundation
    import Testing
    import WaylandRaw
    import WaylandTestSupport

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

        @Test
        func dragIconImageRejectsPixelCountOverflowWithoutTrapping() {
            #expect(
                throws: DataTransferError.invalidDragIconPixelCount(
                    expected: Int.max,
                    actual: 0
                )
            ) {
                _ = try DragIconImage.validatePixelCount(
                    width: Int.max,
                    height: 2,
                    actual: 0
                )
            }
        }

        @Test
        func dragIconSolidImageFillsEveryPixel() throws {
            let size = try PositivePixelSize(width: 2, height: 3)

            let image = try DragIconImage.solid(size: size, color: 0x00AA_55CC)

            #expect(image.size == size)
            #expect(image.pixels == Array(repeating: 0x00AA_55CC, count: 6))
        }

        @Test
        func dragIconRoleSurfaceCopiesAttachesDamagesCommitsAndDestroys() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                try assertDragIconRoleSurfaceEffects()
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

    private func assertDragIconRoleSurfaceEffects() throws {
        swl_test_core_request_recording_begin()
        swl_test_buffer_listener_recording_begin()
        defer {
            swl_test_buffer_listener_recording_end()
            swl_test_core_request_recording_end()
        }

        let pixels: [UInt32] = [0x00FF_0000, 0x0000_FF00]
        var roleSurface: DragIconRoleSurface? = try makeDragIconRoleSurface(pixels: pixels)

        #expect(roleSurface?.committedBytesForTesting() == xrgb8888Bytes(pixels))
        assertDragIconCommitRecord()

        roleSurface?.destroy()
        roleSurface = nil

        let destroyRecord = coreRequestRecord()
        #expect(destroyRecord.surfaceDestroySequence > 0)
        #expect(destroyRecord.bufferDestroySequence > 0)
        #expect(destroyRecord.shmPoolDestroySequence > 0)
    }

    private func makeDragIconRoleSurface(pixels: [UInt32]) throws -> DragIconRoleSurface {
        let context = try leakingProxyAdoptionContext()
        let surface = try RawSurface.testingSurface(
            pointer: fakeOpaquePointer(0xD001),
            version: RawVersion(4),
            proxyAdoption: context
        )
        let sharedMemory = try RawSharedMemory.testingSharedMemory(
            pointer: fakeOpaquePointer(0xD002),
            version: RawVersion(1),
            proxyAdoption: context
        )
        let image = try DragIconImage(
            size: PositivePixelSize(width: 2, height: 1),
            pixels: pixels
        )
        return try DragIconRoleSurface(
            surface: surface,
            sharedMemory: sharedMemory,
            image: image
        )
    }

    private func assertDragIconCommitRecord() {
        let commitRecord = coreRequestRecord()
        #expect(commitRecord.attachSequence > 0)
        #expect(commitRecord.damageSequence > commitRecord.attachSequence)
        #expect(commitRecord.commitSequence > commitRecord.damageSequence)
        #expect(commitRecord.bufferRawValue == 0x5202)
        #expect(commitRecord.width == 2)
        #expect(commitRecord.height == 1)
    }

    private func xrgb8888Bytes(_ pixels: [UInt32]) -> [UInt8] {
        pixels.flatMap { pixel in
            var littleEndianPixel = pixel.littleEndian
            return unsafe withUnsafeBytes(of: &littleEndianPixel) { bytes in
                unsafe Array(bytes)
            }
        }
    }

    private func leakingProxyAdoptionContext() throws -> RawProxyAdoptionContext {
        let queue = RawEventQueue.testingQueueWithoutDestroy(
            opaquePointer: fakeOpaquePointer(0xE001)
        )
        return RawProxyAdoptionContext(eventQueue: queue)
    }

    private struct CoreRequestSnapshot {
        let attachSequence: UInt32
        let damageSequence: UInt32
        let commitSequence: UInt32
        let surfaceDestroySequence: UInt32
        let bufferDestroySequence: UInt32
        let shmPoolDestroySequence: UInt32
        let bufferRawValue: UInt?
        let width: Int32
        let height: Int32
    }

    @safe
    private func coreRequestRecord() -> CoreRequestSnapshot {
        let record = unsafe swl_test_core_request_record()
        return unsafe CoreRequestSnapshot(
            attachSequence: record.attach_sequence,
            damageSequence: record.damage_sequence,
            commitSequence: record.commit_sequence,
            surfaceDestroySequence: record.surface_destroy_sequence,
            bufferDestroySequence: record.buffer_destroy_sequence,
            shmPoolDestroySequence: record.shm_pool_destroy_sequence,
            bufferRawValue: record.buffer.map { UInt(bitPattern: $0) },
            width: record.width,
            height: record.height
        )
    }

    @safe
    private func fakeOpaquePointer(_ bitPattern: UInt) -> OpaquePointer {
        guard let pointer = unsafe OpaquePointer(bitPattern: bitPattern) else {
            preconditionFailure("fake pointer bit pattern must be nonzero")
        }

        return unsafe pointer
    }

#endif
