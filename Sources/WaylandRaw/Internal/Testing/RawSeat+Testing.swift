#if DEBUG
    extension RawSeat {
        package static func testingNoopSeatForRequestRecording(
            id seatID: RawSeatID,
            pointerAddress: Int
        ) throws -> RawSeat {
            guard let seatPointer = unsafe OpaquePointer(bitPattern: pointerAddress) else {
                throw RuntimeError.bindFailed("wl_seat")
            }

            return try unsafe RawSeat(
                id: seatID,
                pointer: seatPointer,
                version: RawVersion(10),
                eventSink: RawInputEventQueue(),
                operations: .testingNoop,
                installListener: false
            )
        }

        package var pointerAddressForTesting: UInt {
            unsafe UInt(bitPattern: UnsafeMutableRawPointer(pointer))
        }
    }
#endif
