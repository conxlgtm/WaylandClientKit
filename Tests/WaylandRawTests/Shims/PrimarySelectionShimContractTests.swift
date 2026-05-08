import CWaylandProtocols
import Testing

@Suite(.serialized)
struct PrimarySelectionOfferShimContractTests {
    @Test
    func primarySelectionOfferListenerForwardsMimeType() throws {
        let data = UnsafeMutableRawPointer(bitPattern: 0x5101)
        let offer = try #require(OpaquePointer(bitPattern: 0x5202))
        var record = swl_test_primary_selection_offer_offer_record()

        try "text/plain;charset=utf-8".withCString { mimeType in
            unsafe swl_test_primary_selection_offer_listener_emit_offer(
                data,
                offer,
                mimeType,
                &record
            )

            let recordedMimeType = try #require(record.mime_type)
            #expect(String(cString: recordedMimeType) == "text/plain;charset=utf-8")
        }

        #expect(record.call_count == 1)
        #expect(record.data == data)
        #expect(record.offer == offer)
    }
}

@Suite(.serialized)
struct PrimarySelectionSourceShimContractTests {
    @Test
    func primarySelectionSourceListenerForwardsSendAndCancelled() throws {
        let data = UnsafeMutableRawPointer(bitPattern: 0x5303)
        let source = try #require(OpaquePointer(bitPattern: 0x5404))

        var sendRecord = swl_test_primary_selection_source_send_record()
        try "text/plain".withCString { mimeType in
            unsafe swl_test_primary_selection_source_listener_emit_send(
                data,
                source,
                mimeType,
                17,
                &sendRecord
            )

            let recordedMimeType = try #require(sendRecord.mime_type)
            #expect(String(cString: recordedMimeType) == "text/plain")
        }
        #expect(sendRecord.call_count == 1)
        #expect(sendRecord.data == data)
        #expect(sendRecord.source == source)
        #expect(sendRecord.fd == 17)

        var lifecycleRecord = swl_test_primary_selection_source_lifecycle_record()
        unsafe swl_test_primary_selection_source_listener_emit_cancelled(
            data,
            source,
            &lifecycleRecord
        )
        #expect(lifecycleRecord.call_count == 1)
        #expect(lifecycleRecord.data == data)
        #expect(lifecycleRecord.source == source)
    }
}

@Suite(.serialized)
struct PrimarySelectionDeviceShimContractTests {
    @Test
    func primarySelectionDeviceListenerForwardsOfferAndSelection() throws {
        let data = UnsafeMutableRawPointer(bitPattern: 0x5505)
        let device = try #require(OpaquePointer(bitPattern: 0x5606))
        let offer = try #require(OpaquePointer(bitPattern: 0x5707))

        var dataOfferRecord = swl_test_primary_selection_device_offer_record()
        unsafe swl_test_primary_selection_device_listener_emit_data_offer(
            data,
            device,
            offer,
            &dataOfferRecord
        )
        #expect(dataOfferRecord.call_count == 1)
        #expect(dataOfferRecord.data == data)
        #expect(dataOfferRecord.device == device)
        #expect(dataOfferRecord.offer == offer)

        var selectionRecord = swl_test_primary_selection_device_offer_record()
        unsafe swl_test_primary_selection_device_listener_emit_selection(
            data,
            device,
            offer,
            &selectionRecord
        )
        #expect(selectionRecord.call_count == 1)
        #expect(selectionRecord.data == data)
        #expect(selectionRecord.device == device)
        #expect(selectionRecord.offer == offer)
    }
}

@Suite(.serialized)
struct PrimarySelectionRequestShimContractTests {
    @Test
    func primarySelectionRequestWrappersPreserveArguments() throws {
        let source = try #require(OpaquePointer(bitPattern: 0x5808))
        let offer = try #require(OpaquePointer(bitPattern: 0x5909))
        let device = try #require(OpaquePointer(bitPattern: 0x5A0A))

        try assertPrimarySelectionRequest(
            expectedKind: SWL_TEST_PRIMARY_SELECTION_SOURCE_OFFER,
            object: source
        ) {
            try "text/plain".withCString { mimeType in
                unsafe swl_primary_selection_source_offer(source, mimeType)
                let record = unsafe swl_test_primary_selection_request_record()
                let recordedMimeType = try #require(record.mime_type)
                #expect(String(cString: recordedMimeType) == "text/plain")
            }
        }

        try assertPrimarySelectionRequest(
            expectedKind: SWL_TEST_PRIMARY_SELECTION_OFFER_RECEIVE,
            object: offer
        ) {
            try "text/uri-list".withCString { mimeType in
                unsafe swl_primary_selection_offer_receive(offer, mimeType, 23)
                let record = unsafe swl_test_primary_selection_request_record()
                let recordedMimeType = try #require(record.mime_type)
                #expect(String(cString: recordedMimeType) == "text/uri-list")
                #expect(record.fd == 23)
            }
        }

        assertPrimarySelectionRequest(
            expectedKind: SWL_TEST_PRIMARY_SELECTION_DEVICE_SET_SELECTION,
            object: device
        ) {
            unsafe swl_primary_selection_device_set_selection(device, source, 101)
            let record = unsafe swl_test_primary_selection_request_record()
            #expect(record.source == UnsafeMutableRawPointer(source))
            #expect(record.serial == 101)
        }
    }

    @Test
    func primarySelectionDestroyWrappersCallMatchingProtocolDestroy() throws {
        assertPrimarySelectionDestroy(
            object: try #require(OpaquePointer(bitPattern: 0x5B0B)),
            expectedKind: SWL_TEST_PRIMARY_SELECTION_DESTROY_OFFER,
            destroy: unsafe swl_primary_selection_offer_destroy
        )
        assertPrimarySelectionDestroy(
            object: try #require(OpaquePointer(bitPattern: 0x5C0C)),
            expectedKind: SWL_TEST_PRIMARY_SELECTION_DESTROY_SOURCE,
            destroy: unsafe swl_primary_selection_source_destroy
        )
        assertPrimarySelectionDestroy(
            object: try #require(OpaquePointer(bitPattern: 0x5D0D)),
            expectedKind: SWL_TEST_PRIMARY_SELECTION_DESTROY_DEVICE,
            destroy: unsafe swl_primary_selection_device_destroy
        )
        assertPrimarySelectionDestroy(
            object: try #require(OpaquePointer(bitPattern: 0x5E0E)),
            expectedKind: SWL_TEST_PRIMARY_SELECTION_DESTROY_MANAGER,
            destroy: unsafe swl_primary_selection_device_manager_destroy
        )
    }
}

private func assertPrimarySelectionRequest(
    expectedKind: swl_test_primary_selection_request_kind,
    object: OpaquePointer,
    exercise: () throws -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) rethrows {
    swl_test_primary_selection_request_recording_begin()
    defer { swl_test_primary_selection_request_recording_end() }

    try exercise()
    let record = unsafe swl_test_primary_selection_request_record()

    #expect(record.call_count == 1, sourceLocation: sourceLocation)
    #expect(record.kind == expectedKind, sourceLocation: sourceLocation)
    #expect(record.object == UnsafeMutableRawPointer(object), sourceLocation: sourceLocation)
}

private func assertPrimarySelectionDestroy(
    object: OpaquePointer,
    expectedKind: swl_test_primary_selection_destroy_kind,
    destroy: (OpaquePointer?) -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    swl_test_primary_selection_request_recording_begin()
    defer { swl_test_primary_selection_request_recording_end() }

    destroy(object)
    let record = unsafe swl_test_primary_selection_destroy_record()

    #expect(record.call_count == 1, sourceLocation: sourceLocation)
    #expect(record.kind == expectedKind, sourceLocation: sourceLocation)
    #expect(record.object == UnsafeMutableRawPointer(object), sourceLocation: sourceLocation)
}
