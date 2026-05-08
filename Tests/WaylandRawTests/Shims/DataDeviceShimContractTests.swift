import CWaylandProtocols
import Testing

@Suite(.serialized)
struct DataOfferShimContractTests {
    @Test
    func dataOfferListenerForwardsMimeAndActions() throws {
        let data = UnsafeMutableRawPointer(bitPattern: 0x1001)
        let offer = try #require(OpaquePointer(bitPattern: 0x2002))
        var offerRecord = swl_test_data_offer_offer_record()

        try "text/plain;charset=utf-8".withCString { mimeType in
            unsafe swl_test_data_offer_listener_emit_offer(data, offer, mimeType, &offerRecord)

            let recordedMimeType = try #require(offerRecord.mime_type)
            #expect(String(cString: recordedMimeType) == "text/plain;charset=utf-8")
        }

        #expect(offerRecord.call_count == 1)
        #expect(offerRecord.data == data)
        #expect(offerRecord.offer == offer)

        var sourceActionsRecord = swl_test_data_offer_action_record()
        unsafe swl_test_data_offer_listener_emit_source_actions(
            data,
            offer,
            3,
            &sourceActionsRecord
        )
        #expect(sourceActionsRecord.call_count == 1)
        #expect(sourceActionsRecord.data == data)
        #expect(sourceActionsRecord.offer == offer)
        #expect(sourceActionsRecord.action == 3)

        var actionRecord = swl_test_data_offer_action_record()
        unsafe swl_test_data_offer_listener_emit_action(data, offer, 2, &actionRecord)
        #expect(actionRecord.call_count == 1)
        #expect(actionRecord.data == data)
        #expect(actionRecord.offer == offer)
        #expect(actionRecord.action == 2)
    }
}

@Suite(.serialized)
struct DataSourceShimContractTests {
    @Test
    func dataSourceListenerForwardsTargetSendLifecycleAndAction() throws {
        let data = UnsafeMutableRawPointer(bitPattern: 0x3003)
        let source = try #require(OpaquePointer(bitPattern: 0x4004))

        try assertDataSourceTarget(data: data, source: source)
        try assertDataSourceSend(data: data, source: source)
        assertDataSourceLifecycle(
            data: data,
            source: source,
            emit: unsafe swl_test_data_source_listener_emit_cancelled
        )
        assertDataSourceLifecycle(
            data: data,
            source: source,
            emit: unsafe swl_test_data_source_listener_emit_dnd_drop_performed
        )
        assertDataSourceLifecycle(
            data: data,
            source: source,
            emit: unsafe swl_test_data_source_listener_emit_dnd_finished
        )

        var actionRecord = swl_test_data_source_action_record()
        unsafe swl_test_data_source_listener_emit_action(data, source, 4, &actionRecord)
        #expect(actionRecord.call_count == 1)
        #expect(actionRecord.data == data)
        #expect(actionRecord.source == source)
        #expect(actionRecord.action == 4)
    }
}

@Suite(.serialized)
struct DataDeviceShimContractTests {
    @Test
    func dataDeviceListenerForwardsOffersMotionLifecycleAndSelection() throws {
        let data = UnsafeMutableRawPointer(bitPattern: 0x5005)
        let device = try #require(OpaquePointer(bitPattern: 0x6006))
        let surface = try #require(OpaquePointer(bitPattern: 0x7007))
        let offer = try #require(OpaquePointer(bitPattern: 0x8008))

        assertDataDeviceOffer(data: data, device: device, offer: offer)
        assertDataDeviceEnter(data: data, device: device, surface: surface, offer: offer)
        assertDataDeviceMotion(data: data, device: device)
        assertDataDeviceLifecycle(
            data: data,
            device: device,
            emit: unsafe swl_test_data_device_listener_emit_leave
        )
        assertDataDeviceLifecycle(
            data: data,
            device: device,
            emit: unsafe swl_test_data_device_listener_emit_drop
        )
        assertDataDeviceSelection(data: data, device: device, offer: offer)
    }
}

@Suite(.serialized)
struct DataDeviceRequestShimContractTests {
    @Test
    func dataSourceRequestWrappersPreserveArguments() throws {
        let source = try #require(OpaquePointer(bitPattern: 0x9009))

        try assertDataRequest(expectedKind: SWL_TEST_DATA_SOURCE_OFFER, object: source) {
            try "text/plain".withCString { mimeType in
                unsafe swl_data_source_offer(source, mimeType)
                let record = unsafe swl_test_data_request_record()
                let recordedMimeType = try #require(record.mime_type)
                #expect(String(cString: recordedMimeType) == "text/plain")
            }
        }

        assertDataRequest(expectedKind: SWL_TEST_DATA_SOURCE_SET_ACTIONS, object: source) {
            unsafe swl_data_source_set_actions(source, 7)
            let record = unsafe swl_test_data_request_record()
            #expect(record.actions == 7)
        }
    }

    @Test
    func dataOfferRequestWrappersPreserveArguments() throws {
        let offer = try #require(OpaquePointer(bitPattern: 0xA00A))

        try assertDataRequest(expectedKind: SWL_TEST_DATA_OFFER_ACCEPT, object: offer) {
            try "text/uri-list".withCString { mimeType in
                unsafe swl_data_offer_accept(offer, 77, mimeType)
                let record = unsafe swl_test_data_request_record()
                let recordedMimeType = try #require(record.mime_type)
                #expect(String(cString: recordedMimeType) == "text/uri-list")
                #expect(record.serial == 77)
            }
        }

        try assertDataRequest(expectedKind: SWL_TEST_DATA_OFFER_RECEIVE, object: offer) {
            try "text/plain;charset=utf-8".withCString { mimeType in
                unsafe swl_data_offer_receive(offer, mimeType, 14)
                let record = unsafe swl_test_data_request_record()
                let recordedMimeType = try #require(record.mime_type)
                #expect(String(cString: recordedMimeType) == "text/plain;charset=utf-8")
                #expect(record.fd == 14)
            }
        }

        assertDataRequest(expectedKind: SWL_TEST_DATA_OFFER_FINISH, object: offer) {
            unsafe swl_data_offer_finish(offer)
        }

        assertDataRequest(expectedKind: SWL_TEST_DATA_OFFER_SET_ACTIONS, object: offer) {
            unsafe swl_data_offer_set_actions(offer, 6, 2)
            let record = unsafe swl_test_data_request_record()
            #expect(record.actions == 6)
            #expect(record.preferred_action == 2)
        }
    }

    @Test
    func dataDeviceRequestWrappersPreserveArguments() throws {
        let source = try #require(OpaquePointer(bitPattern: 0x9009))
        let device = try #require(OpaquePointer(bitPattern: 0xB00B))
        let origin = try #require(OpaquePointer(bitPattern: 0xC00C))
        let icon = try #require(OpaquePointer(bitPattern: 0xD00D))

        assertDataRequest(expectedKind: SWL_TEST_DATA_DEVICE_SET_SELECTION, object: device) {
            unsafe swl_data_device_set_selection(device, source, 88)
            let record = unsafe swl_test_data_request_record()
            #expect(record.source == UnsafeMutableRawPointer(source))
            #expect(record.serial == 88)
        }

        assertDataRequest(expectedKind: SWL_TEST_DATA_DEVICE_START_DRAG, object: device) {
            unsafe swl_data_device_start_drag(device, source, origin, icon, 99)
            let record = unsafe swl_test_data_request_record()
            #expect(record.source == UnsafeMutableRawPointer(source))
            #expect(record.origin == UnsafeMutableRawPointer(origin))
            #expect(record.icon == UnsafeMutableRawPointer(icon))
            #expect(record.serial == 99)
        }
    }

    @Test
    func dataDestroyWrappersCallTheMatchingProtocolDestroy() throws {
        assertDataDestroy(
            object: try #require(OpaquePointer(bitPattern: 0xE00E)),
            expectedKind: SWL_TEST_DATA_DESTROY_OFFER,
            destroy: unsafe swl_data_offer_destroy
        )
        assertDataDestroy(
            object: try #require(OpaquePointer(bitPattern: 0xF00F)),
            expectedKind: SWL_TEST_DATA_DESTROY_SOURCE,
            destroy: unsafe swl_data_source_destroy
        )
        assertDataDestroy(
            object: try #require(OpaquePointer(bitPattern: 0xABCD)),
            expectedKind: SWL_TEST_DATA_DESTROY_DEVICE_LEGACY,
            destroy: unsafe swl_data_device_destroy
        )
        assertDataDestroy(
            object: try #require(OpaquePointer(bitPattern: 0xBCDE)),
            expectedKind: SWL_TEST_DATA_DESTROY_DEVICE,
            destroy: unsafe swl_data_device_release
        )
        assertDataDestroy(
            object: try #require(OpaquePointer(bitPattern: 0xCDEF)),
            expectedKind: SWL_TEST_DATA_DESTROY_MANAGER,
            destroy: unsafe swl_data_device_manager_destroy
        )
    }
}

private func assertDataSourceTarget(
    data: UnsafeMutableRawPointer?,
    source: OpaquePointer
) throws {
    var record = swl_test_data_source_send_record()
    try "text/uri-list".withCString { mimeType in
        unsafe swl_test_data_source_listener_emit_target(data, source, mimeType, &record)

        let recordedMimeType = try #require(record.mime_type)
        #expect(String(cString: recordedMimeType) == "text/uri-list")
    }
    #expect(record.call_count == 1)
    #expect(record.data == data)
    #expect(record.source == source)
    #expect(record.fd == -1)
}

private func assertDataSourceSend(
    data: UnsafeMutableRawPointer?,
    source: OpaquePointer
) throws {
    var record = swl_test_data_source_send_record()
    try "text/plain".withCString { mimeType in
        unsafe swl_test_data_source_listener_emit_send(data, source, mimeType, 12, &record)

        let recordedMimeType = try #require(record.mime_type)
        #expect(String(cString: recordedMimeType) == "text/plain")
    }
    #expect(record.call_count == 1)
    #expect(record.data == data)
    #expect(record.source == source)
    #expect(record.fd == 12)
}

private func assertDataDeviceOffer(
    data: UnsafeMutableRawPointer?,
    device: OpaquePointer,
    offer: OpaquePointer
) {
    var record = swl_test_data_device_offer_record()
    unsafe swl_test_data_device_listener_emit_data_offer(data, device, offer, &record)
    #expect(record.call_count == 1)
    #expect(record.data == data)
    #expect(record.device == device)
    #expect(record.offer == offer)
}

private func assertDataDeviceEnter(
    data: UnsafeMutableRawPointer?,
    device: OpaquePointer,
    surface: OpaquePointer,
    offer: OpaquePointer
) {
    var record = swl_test_data_device_enter_record()
    unsafe swl_test_data_device_listener_emit_enter(
        data,
        device,
        55,
        surface,
        1_024,
        2_048,
        offer,
        &record
    )
    #expect(record.call_count == 1)
    #expect(record.data == data)
    #expect(record.device == device)
    #expect(record.serial == 55)
    #expect(record.surface == surface)
    #expect(record.x == 1_024)
    #expect(record.y == 2_048)
    #expect(record.offer == offer)
}

private func assertDataDeviceMotion(
    data: UnsafeMutableRawPointer?,
    device: OpaquePointer
) {
    var record = swl_test_data_device_motion_record()
    unsafe swl_test_data_device_listener_emit_motion(data, device, 99, 4_096, 8_192, &record)
    #expect(record.call_count == 1)
    #expect(record.data == data)
    #expect(record.device == device)
    #expect(record.time == 99)
    #expect(record.x == 4_096)
    #expect(record.y == 8_192)
}

private func assertDataDeviceSelection(
    data: UnsafeMutableRawPointer?,
    device: OpaquePointer,
    offer: OpaquePointer
) {
    var record = swl_test_data_device_offer_record()
    unsafe swl_test_data_device_listener_emit_selection(data, device, offer, &record)
    #expect(record.call_count == 1)
    #expect(record.data == data)
    #expect(record.device == device)
    #expect(record.offer == offer)
}

private func assertDataSourceLifecycle(
    data: UnsafeMutableRawPointer?,
    source: OpaquePointer,
    emit: (
        UnsafeMutableRawPointer?,
        OpaquePointer?,
        UnsafeMutablePointer<swl_test_data_source_lifecycle_record>?
    ) -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    var record = swl_test_data_source_lifecycle_record()
    emit(data, source, &record)
    #expect(record.call_count == 1, sourceLocation: sourceLocation)
    #expect(record.data == data, sourceLocation: sourceLocation)
    #expect(record.source == source, sourceLocation: sourceLocation)
}

private func assertDataDeviceLifecycle(
    data: UnsafeMutableRawPointer?,
    device: OpaquePointer,
    emit: (
        UnsafeMutableRawPointer?,
        OpaquePointer?,
        UnsafeMutablePointer<swl_test_data_device_lifecycle_record>?
    ) -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    var record = swl_test_data_device_lifecycle_record()
    emit(data, device, &record)
    #expect(record.call_count == 1, sourceLocation: sourceLocation)
    #expect(record.data == data, sourceLocation: sourceLocation)
    #expect(record.device == device, sourceLocation: sourceLocation)
}

private func assertDataRequest(
    expectedKind: swl_test_data_request_kind,
    object: OpaquePointer,
    exercise: () throws -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) rethrows {
    swl_test_data_request_recording_begin()
    defer { swl_test_data_request_recording_end() }

    try exercise()
    let record = unsafe swl_test_data_request_record()

    #expect(record.call_count == 1, sourceLocation: sourceLocation)
    #expect(record.kind == expectedKind, sourceLocation: sourceLocation)
    #expect(record.object == UnsafeMutableRawPointer(object), sourceLocation: sourceLocation)
}

private func assertDataDestroy(
    object: OpaquePointer,
    expectedKind: swl_test_data_destroy_kind,
    destroy: (OpaquePointer?) -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    swl_test_data_request_recording_begin()
    defer { swl_test_data_request_recording_end() }

    destroy(object)
    let record = unsafe swl_test_data_destroy_record()

    #expect(record.call_count == 1, sourceLocation: sourceLocation)
    #expect(record.kind == expectedKind, sourceLocation: sourceLocation)
    #expect(record.object == UnsafeMutableRawPointer(object), sourceLocation: sourceLocation)
}
