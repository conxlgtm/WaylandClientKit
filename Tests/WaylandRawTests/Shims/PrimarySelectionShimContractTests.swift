import CWaylandProtocols
import Testing

@Suite(.serialized)
struct PrimarySelectionOfferShimContractTests {
    @Test
    func primarySelectionOfferListenerForwardsMimeType() throws {
        let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x5101)
        let offer = try unsafe #require(OpaquePointer(bitPattern: 0x5202))
        var record = unsafe swl_test_primary_selection_offer_offer_record()
        try unsafe "text/plain;charset=utf-8".withCString { mimeType in
            unsafe swl_test_primary_selection_offer_listener_emit_offer(
                data,
                offer,
                mimeType,
                &record
            )
            let recordedMimeType = try unsafe #require(record.mime_type)
            #expect(unsafe String(cString: recordedMimeType) == "text/plain;charset=utf-8")
        }
        #expect(unsafe record.call_count == 1)
        #expect(unsafe record.data == data)
        #expect(unsafe record.offer == offer)
    }
}
@Suite(.serialized)
struct PrimarySelectionSourceShimContractTests {
    @Test
    func primarySelectionSourceListenerForwardsSendAndCancelled() throws {
        let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x5303)
        let source = try unsafe #require(OpaquePointer(bitPattern: 0x5404))
        var sendRecord = unsafe swl_test_primary_selection_source_send_record()
        try unsafe "text/plain".withCString { mimeType in
            unsafe swl_test_primary_selection_source_listener_emit_send(
                data,
                source,
                mimeType,
                17,
                &sendRecord
            )
            let recordedMimeType = try unsafe #require(sendRecord.mime_type)
            #expect(unsafe String(cString: recordedMimeType) == "text/plain")
        }
        #expect(unsafe sendRecord.call_count == 1)
        #expect(unsafe sendRecord.data == data)
        #expect(unsafe sendRecord.source == source)
        #expect(unsafe sendRecord.fd == 17)
        var lifecycleRecord = unsafe swl_test_primary_selection_source_lifecycle_record()
        unsafe swl_test_primary_selection_source_listener_emit_cancelled(
            data,
            source,
            &lifecycleRecord
        )
        #expect(unsafe lifecycleRecord.call_count == 1)
        #expect(unsafe lifecycleRecord.data == data)
        #expect(unsafe lifecycleRecord.source == source)
    }
}
@Suite(.serialized)
struct PrimarySelectionDeviceShimContractTests {
    @Test
    func primarySelectionDeviceListenerForwardsOfferAndSelection() throws {
        let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x5505)
        let device = try unsafe #require(OpaquePointer(bitPattern: 0x5606))
        let offer = try unsafe #require(OpaquePointer(bitPattern: 0x5707))
        var dataOfferRecord = unsafe swl_test_primary_selection_device_offer_record()
        unsafe swl_test_primary_selection_device_listener_emit_data_offer(
            data,
            device,
            offer,
            &dataOfferRecord
        )
        #expect(unsafe dataOfferRecord.call_count == 1)
        #expect(unsafe dataOfferRecord.data == data)
        #expect(unsafe dataOfferRecord.device == device)
        #expect(unsafe dataOfferRecord.offer == offer)
        var selectionRecord = unsafe swl_test_primary_selection_device_offer_record()
        unsafe swl_test_primary_selection_device_listener_emit_selection(
            data,
            device,
            offer,
            &selectionRecord
        )
        #expect(unsafe selectionRecord.call_count == 1)
        #expect(unsafe selectionRecord.data == data)
        #expect(unsafe selectionRecord.device == device)
        #expect(unsafe selectionRecord.offer == offer)
    }
}
@Suite(.serialized)
struct PrimarySelectionRequestShimContractTests {
    @Test
    func primarySelectionRequestWrappersPreserveArguments() throws {
        let source = try unsafe #require(OpaquePointer(bitPattern: 0x5808))
        let offer = try unsafe #require(OpaquePointer(bitPattern: 0x5909))
        let device = try unsafe #require(OpaquePointer(bitPattern: 0x5A0A))
        try assertPrimarySelectionRequest(
            expectedKind: SWL_TEST_PRIMARY_SELECTION_SOURCE_OFFER,
            object: unsafe source
        ) {
            try unsafe "text/plain".withCString { mimeType in
                unsafe swl_primary_selection_source_offer(source, mimeType)
                let record = unsafe swl_test_primary_selection_request_record()
                let recordedMimeType = try unsafe #require(record.mime_type)
                #expect(unsafe String(cString: recordedMimeType) == "text/plain")
            }
        }
        try assertPrimarySelectionRequest(
            expectedKind: SWL_TEST_PRIMARY_SELECTION_OFFER_RECEIVE,
            object: unsafe offer
        ) {
            try unsafe "text/uri-list".withCString { mimeType in
                unsafe swl_primary_selection_offer_receive(offer, mimeType, 23)
                let record = unsafe swl_test_primary_selection_request_record()
                let recordedMimeType = try unsafe #require(record.mime_type)
                #expect(unsafe String(cString: recordedMimeType) == "text/uri-list")
                #expect(unsafe record.fd == 23)
            }
        }
        assertPrimarySelectionRequest(
            expectedKind: SWL_TEST_PRIMARY_SELECTION_DEVICE_SET_SELECTION,
            object: unsafe device
        ) {
            unsafe swl_primary_selection_device_set_selection(device, source, 101)
            let record = unsafe swl_test_primary_selection_request_record()
            let expectedSource = unsafe UnsafeMutableRawPointer(source)
            #expect(unsafe record.source == expectedSource)
            #expect(unsafe record.serial == 101)
        }
    }
    @Test
    func primarySelectionDestroyWrappersCallMatchingProtocolDestroy() throws {
        assertPrimarySelectionDestroy(
            object: try unsafe #require(OpaquePointer(bitPattern: 0x5B0B)),
            expectedKind: SWL_TEST_PRIMARY_SELECTION_DESTROY_OFFER,
            destroy: unsafe swl_primary_selection_offer_destroy
        )
        assertPrimarySelectionDestroy(
            object: try unsafe #require(OpaquePointer(bitPattern: 0x5C0C)),
            expectedKind: SWL_TEST_PRIMARY_SELECTION_DESTROY_SOURCE,
            destroy: unsafe swl_primary_selection_source_destroy
        )
        assertPrimarySelectionDestroy(
            object: try unsafe #require(OpaquePointer(bitPattern: 0x5D0D)),
            expectedKind: SWL_TEST_PRIMARY_SELECTION_DESTROY_DEVICE,
            destroy: unsafe swl_primary_selection_device_destroy
        )
        assertPrimarySelectionDestroy(
            object: try unsafe #require(OpaquePointer(bitPattern: 0x5E0E)),
            expectedKind: SWL_TEST_PRIMARY_SELECTION_DESTROY_MANAGER,
            destroy: unsafe swl_primary_selection_device_manager_destroy
        )
    }
}

@safe
private func assertPrimarySelectionRequest(
    expectedKind: swl_test_primary_selection_request_kind,
    object: OpaquePointer,
    exercise: () throws -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) rethrows {
    unsafe swl_test_primary_selection_request_recording_begin()
    defer { unsafe swl_test_primary_selection_request_recording_end() }
    try exercise()
    let record = unsafe swl_test_primary_selection_request_record()
    let expectedObject = unsafe UnsafeMutableRawPointer(object)
    #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
    #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
    #expect(unsafe record.object == expectedObject, sourceLocation: sourceLocation)
}

@safe
private func assertPrimarySelectionDestroy(
    object: OpaquePointer,
    expectedKind: swl_test_primary_selection_destroy_kind,
    destroy: (OpaquePointer?) -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    unsafe swl_test_primary_selection_request_recording_begin()
    defer { unsafe swl_test_primary_selection_request_recording_end() }
    unsafe destroy(object)
    let record = unsafe swl_test_primary_selection_destroy_record()
    let expectedObject = unsafe UnsafeMutableRawPointer(object)
    #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
    #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
    #expect(unsafe record.object == expectedObject, sourceLocation: sourceLocation)
}
