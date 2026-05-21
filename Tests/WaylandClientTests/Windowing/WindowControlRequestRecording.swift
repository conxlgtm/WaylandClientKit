#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    func recordTopLevelRequest(
        _ request: @Sendable () async throws -> Void
    ) async throws -> RecordedTopLevelRequest {
        try await XDGRequestRecordingGate.withExclusiveRecording {
            swl_test_xdg_request_recording_begin()
            defer {
                swl_test_xdg_request_recording_end()
            }

            try await request()
            let record = unsafe RecordedTopLevelRequest(swl_test_xdg_toplevel_request_record())
            #expect(record.callCount == 1)
            return record
        }
    }

    struct RecordedTopLevelRequest: Sendable {
        let callCount: Int32
        let kind: swl_test_xdg_toplevel_request_kind
        let topLevelAddress: UInt?
        let seatAddress: UInt?
        let outputAddress: UInt?
        let serial: UInt32
        let x: Int32
        let y: Int32
        let width: Int32
        let height: Int32
        let value: UInt32
        let text: String?

        init(_ record: swl_test_xdg_toplevel_request_record) {
            unsafe callCount = record.call_count
            unsafe kind = record.kind
            unsafe topLevelAddress = Self.pointerAddress(record.toplevel)
            unsafe seatAddress = Self.pointerAddress(record.seat)
            unsafe outputAddress = Self.pointerAddress(record.output)
            unsafe serial = record.serial
            unsafe x = record.x
            unsafe y = record.y
            unsafe width = record.width
            unsafe height = record.height
            unsafe value = record.value
            if let rawText = unsafe record.text {
                text = unsafe String(cString: rawText)
            } else {
                text = nil
            }
        }

        private static func pointerAddress(_ pointer: OpaquePointer?) -> UInt? {
            guard let pointer = unsafe pointer else { return nil }

            return unsafe UInt(bitPattern: UnsafeMutableRawPointer(pointer))
        }
    }

#endif
