import CWaylandProtocols
import Testing

@Suite(.serialized)
struct DataOfferShimContractTests {
    @Test
    func dataOfferListenerForwardsMimeAndActions() throws {
        let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x1001)
        let offer = try unsafe #require(OpaquePointer(bitPattern: 0x2002))
        var offerRecord = unsafe swl_test_data_offer_offer_record()
        try unsafe "text/plain;charset=utf-8".withCString { mimeType in
            unsafe swl_test_data_offer_listener_emit_offer(data, offer, mimeType, &offerRecord)
            let recordedMimeType = try unsafe #require(offerRecord.mime_type)
            #expect(unsafe String(cString: recordedMimeType) == "text/plain;charset=utf-8")
        }
        #expect(unsafe offerRecord.call_count == 1)
        #expect(unsafe offerRecord.data == data)
        #expect(unsafe offerRecord.offer == offer)
        var sourceActionsRecord = unsafe swl_test_data_offer_action_record()
        unsafe swl_test_data_offer_listener_emit_source_actions(
            data,
            offer,
            3,
            &sourceActionsRecord
        )
        #expect(unsafe sourceActionsRecord.call_count == 1)
        #expect(unsafe sourceActionsRecord.data == data)
        #expect(unsafe sourceActionsRecord.offer == offer)
        #expect(unsafe sourceActionsRecord.action == 3)
        var actionRecord = unsafe swl_test_data_offer_action_record()
        unsafe swl_test_data_offer_listener_emit_action(data, offer, 2, &actionRecord)
        #expect(unsafe actionRecord.call_count == 1)
        #expect(unsafe actionRecord.data == data)
        #expect(unsafe actionRecord.offer == offer)
        #expect(unsafe actionRecord.action == 2)
    }
}
@Suite(.serialized)
struct DataSourceShimContractTests {
    @Test
    func dataSourceListenerForwardsTargetSendLifecycleAndAction() throws {
        let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x3003)
        let source = try unsafe #require(OpaquePointer(bitPattern: 0x4004))
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
        var actionRecord = unsafe swl_test_data_source_action_record()
        unsafe swl_test_data_source_listener_emit_action(data, source, 4, &actionRecord)
        #expect(unsafe actionRecord.call_count == 1)
        #expect(unsafe actionRecord.data == data)
        #expect(unsafe actionRecord.source == source)
        #expect(unsafe actionRecord.action == 4)
    }
}
@Suite(.serialized)
struct DataDeviceShimContractTests {
    @Test
    func dataDeviceListenerForwardsOffersMotionLifecycleAndSelection() throws {
        let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x5005)
        let device = try unsafe #require(OpaquePointer(bitPattern: 0x6006))
        let surface = try unsafe #require(OpaquePointer(bitPattern: 0x7007))
        let offer = try unsafe #require(OpaquePointer(bitPattern: 0x8008))
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
        let source = try unsafe #require(OpaquePointer(bitPattern: 0x9009))
        try assertDataRequest(expectedKind: SWL_TEST_DATA_SOURCE_OFFER, object: source) {
            try unsafe "text/plain".withCString { mimeType in
                unsafe swl_data_source_offer(source, mimeType)
                let record = unsafe swl_test_data_request_record()
                let recordedMimeType = try unsafe #require(record.mime_type)
                #expect(unsafe String(cString: recordedMimeType) == "text/plain")
            }
        }
        assertDataRequest(expectedKind: SWL_TEST_DATA_SOURCE_SET_ACTIONS, object: source) {
            unsafe swl_data_source_set_actions(source, 7)
            let record = unsafe swl_test_data_request_record()
            #expect(unsafe record.actions == 7)
        }
    }
    @Test
    func dataOfferRequestWrappersPreserveArguments() throws {
        let offer = try unsafe #require(OpaquePointer(bitPattern: 0xA00A))
        try assertDataRequest(expectedKind: SWL_TEST_DATA_OFFER_ACCEPT, object: offer) {
            try unsafe "text/uri-list".withCString { mimeType in
                unsafe swl_data_offer_accept(offer, 77, mimeType)
                let record = unsafe swl_test_data_request_record()
                let recordedMimeType = try unsafe #require(record.mime_type)
                #expect(unsafe String(cString: recordedMimeType) == "text/uri-list")
                #expect(unsafe record.serial == 77)
            }
        }
        try assertDataRequest(expectedKind: SWL_TEST_DATA_OFFER_RECEIVE, object: offer) {
            try unsafe "text/plain;charset=utf-8".withCString { mimeType in
                unsafe swl_data_offer_receive(offer, mimeType, 14)
                let record = unsafe swl_test_data_request_record()
                let recordedMimeType = try unsafe #require(record.mime_type)
                #expect(unsafe String(cString: recordedMimeType) == "text/plain;charset=utf-8")
                #expect(unsafe record.fd == 14)
            }
        }
        assertDataRequest(expectedKind: SWL_TEST_DATA_OFFER_FINISH, object: offer) {
            unsafe swl_data_offer_finish(offer)
        }
        assertDataRequest(expectedKind: SWL_TEST_DATA_OFFER_SET_ACTIONS, object: offer) {
            unsafe swl_data_offer_set_actions(offer, 6, 2)
            let record = unsafe swl_test_data_request_record()
            #expect(unsafe record.actions == 6)
            #expect(unsafe record.preferred_action == 2)
        }
    }
    @Test
    func dataDeviceRequestWrappersPreserveArguments() throws {
        let source = try unsafe #require(OpaquePointer(bitPattern: 0x9009))
        let device = try unsafe #require(OpaquePointer(bitPattern: 0xB00B))
        let origin = try unsafe #require(OpaquePointer(bitPattern: 0xC00C))
        let icon = try unsafe #require(OpaquePointer(bitPattern: 0xD00D))
        assertDataRequest(expectedKind: SWL_TEST_DATA_DEVICE_SET_SELECTION, object: device) {
            unsafe swl_data_device_set_selection(device, source, 88)
            let record = unsafe swl_test_data_request_record()
            let expectedSource = unsafe UnsafeMutableRawPointer(source)
            #expect(unsafe record.source == expectedSource)
            #expect(unsafe record.serial == 88)
        }
        assertDataRequest(expectedKind: SWL_TEST_DATA_DEVICE_START_DRAG, object: device) {
            unsafe swl_data_device_start_drag(device, source, origin, icon, 99)
            let record = unsafe swl_test_data_request_record()
            let expectedSource = unsafe UnsafeMutableRawPointer(source)
            let expectedOrigin = unsafe UnsafeMutableRawPointer(origin)
            let expectedIcon = unsafe UnsafeMutableRawPointer(icon)
            #expect(unsafe record.source == expectedSource)
            #expect(unsafe record.origin == expectedOrigin)
            #expect(unsafe record.icon == expectedIcon)
            #expect(unsafe record.serial == 99)
        }
    }
    @Test
    func dataDestroyWrappersCallTheMatchingProtocolDestroy() throws {
        assertDataDestroy(
            object: try unsafe #require(OpaquePointer(bitPattern: 0xE00E)),
            expectedKind: SWL_TEST_DATA_DESTROY_OFFER,
            destroy: unsafe swl_data_offer_destroy
        )
        assertDataDestroy(
            object: try unsafe #require(OpaquePointer(bitPattern: 0xF00F)),
            expectedKind: SWL_TEST_DATA_DESTROY_SOURCE,
            destroy: unsafe swl_data_source_destroy
        )
        assertDataDestroy(
            object: try unsafe #require(OpaquePointer(bitPattern: 0xABCD)),
            expectedKind: SWL_TEST_DATA_DESTROY_DEVICE_LEGACY,
            destroy: unsafe swl_data_device_destroy
        )
        assertDataDestroy(
            object: try unsafe #require(OpaquePointer(bitPattern: 0xBCDE)),
            expectedKind: SWL_TEST_DATA_DESTROY_DEVICE,
            destroy: unsafe swl_data_device_release
        )
        assertDataDestroy(
            object: try unsafe #require(OpaquePointer(bitPattern: 0xCDEF)),
            expectedKind: SWL_TEST_DATA_DESTROY_MANAGER,
            destroy: unsafe swl_data_device_manager_destroy
        )
    }
}

@safe
private func assertDataSourceTarget(
    data: UnsafeMutableRawPointer?,
    source: OpaquePointer
) throws {
    var record = unsafe swl_test_data_source_send_record()
    try unsafe "text/uri-list".withCString { mimeType in
        unsafe swl_test_data_source_listener_emit_target(data, source, mimeType, &record)
        let recordedMimeType = try unsafe #require(record.mime_type)
        #expect(unsafe String(cString: recordedMimeType) == "text/uri-list")
    }
    #expect(unsafe record.call_count == 1)
    #expect(unsafe record.data == data)
    #expect(unsafe record.source == source)
    #expect(unsafe record.fd == -1)
}

@safe
private func assertDataSourceSend(
    data: UnsafeMutableRawPointer?,
    source: OpaquePointer
) throws {
    var record = unsafe swl_test_data_source_send_record()
    try unsafe "text/plain".withCString { mimeType in
        unsafe swl_test_data_source_listener_emit_send(data, source, mimeType, 12, &record)
        let recordedMimeType = try unsafe #require(record.mime_type)
        #expect(unsafe String(cString: recordedMimeType) == "text/plain")
    }
    #expect(unsafe record.call_count == 1)
    #expect(unsafe record.data == data)
    #expect(unsafe record.source == source)
    #expect(unsafe record.fd == 12)
}

@safe
private func assertDataDeviceOffer(
    data: UnsafeMutableRawPointer?,
    device: OpaquePointer,
    offer: OpaquePointer
) {
    var record = unsafe swl_test_data_device_offer_record()
    unsafe swl_test_data_device_listener_emit_data_offer(data, device, offer, &record)
    #expect(unsafe record.call_count == 1)
    #expect(unsafe record.data == data)
    #expect(unsafe record.device == device)
    #expect(unsafe record.offer == offer)
}

@safe
private func assertDataDeviceEnter(
    data: UnsafeMutableRawPointer?,
    device: OpaquePointer,
    surface: OpaquePointer,
    offer: OpaquePointer
) {
    var record = unsafe swl_test_data_device_enter_record()
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
    #expect(unsafe record.call_count == 1)
    #expect(unsafe record.data == data)
    #expect(unsafe record.device == device)
    #expect(unsafe record.serial == 55)
    #expect(unsafe record.surface == surface)
    #expect(unsafe record.x == 1_024)
    #expect(unsafe record.y == 2_048)
    #expect(unsafe record.offer == offer)
}

@safe
private func assertDataDeviceMotion(
    data: UnsafeMutableRawPointer?,
    device: OpaquePointer
) {
    var record = unsafe swl_test_data_device_motion_record()
    unsafe swl_test_data_device_listener_emit_motion(data, device, 99, 4_096, 8_192, &record)
    #expect(unsafe record.call_count == 1)
    #expect(unsafe record.data == data)
    #expect(unsafe record.device == device)
    #expect(unsafe record.time == 99)
    #expect(unsafe record.x == 4_096)
    #expect(unsafe record.y == 8_192)
}

@safe
private func assertDataDeviceSelection(
    data: UnsafeMutableRawPointer?,
    device: OpaquePointer,
    offer: OpaquePointer
) {
    var record = unsafe swl_test_data_device_offer_record()
    unsafe swl_test_data_device_listener_emit_selection(data, device, offer, &record)
    #expect(unsafe record.call_count == 1)
    #expect(unsafe record.data == data)
    #expect(unsafe record.device == device)
    #expect(unsafe record.offer == offer)
}

@safe
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
    var record = unsafe swl_test_data_source_lifecycle_record()
    unsafe emit(data, source, &record)
    #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
    #expect(unsafe record.data == data, sourceLocation: sourceLocation)
    #expect(unsafe record.source == source, sourceLocation: sourceLocation)
}

@safe
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
    var record = unsafe swl_test_data_device_lifecycle_record()
    unsafe emit(data, device, &record)
    #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
    #expect(unsafe record.data == data, sourceLocation: sourceLocation)
    #expect(unsafe record.device == device, sourceLocation: sourceLocation)
}

@safe
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
    let expectedObject = unsafe UnsafeMutableRawPointer(object)
    #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
    #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
    #expect(unsafe record.object == expectedObject, sourceLocation: sourceLocation)
}

@safe
private func assertDataDestroy(
    object: OpaquePointer,
    expectedKind: swl_test_data_destroy_kind,
    destroy: (OpaquePointer?) -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    swl_test_data_request_recording_begin()
    defer { swl_test_data_request_recording_end() }
    unsafe destroy(object)
    let record = unsafe swl_test_data_destroy_record()
    let expectedObject = unsafe UnsafeMutableRawPointer(object)
    #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
    #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
    #expect(unsafe record.object == expectedObject, sourceLocation: sourceLocation)
}
