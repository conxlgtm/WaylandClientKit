import CWaylandProtocols
import Testing
import WaylandTestSupport

@testable import WaylandRaw

func withMetadataRequestRecording(
    _ operation: () throws -> Void
) async throws {
    try await MetadataRequestRecordingGate.withExclusiveRecording {
        swl_test_metadata_request_recording_begin()
        defer { swl_test_metadata_request_recording_end() }
        try operation()
    }
}

func withCoreAndMetadataRequestRecording(
    _ operation: () throws -> Void
) async throws {
    try await CoreRequestRecordingGate.withExclusiveRecording {
        try await withMetadataRequestRecording {
            swl_test_core_request_recording_begin()
            defer { swl_test_core_request_recording_end() }
            try operation()
        }
    }
}

func withCoreMetadataRequestAndListenerRecording(
    _ operation: () throws -> Void
) async throws {
    try await CoreRequestRecordingGate.withExclusiveRecording {
        try await MetadataRequestRecordingGate.withExclusiveRecording {
            swl_test_core_request_recording_begin()
            swl_test_metadata_request_recording_begin()
            swl_test_metadata_listener_recording_begin()
            defer { swl_test_metadata_listener_recording_end() }
            defer { swl_test_metadata_request_recording_end() }
            defer { swl_test_core_request_recording_end() }
            try operation()
        }
    }
}

func expectMetadataRequest(
    kind expectedKind: swl_test_metadata_request_kind,
    callCount expectedCallCount: Int32,
    object expectedObject: UInt? = nil,
    surface expectedSurface: UInt? = nil,
    reference expectedReference: UInt? = nil,
    imageDescription expectedImageDescription: UInt? = nil,
    value expectedValue: UInt32? = nil,
    coefficients expectedCoefficients: UInt32? = nil,
    range expectedRange: UInt32? = nil,
    renderIntent expectedRenderIntent: UInt32? = nil
) {
    let record = unsafe swl_test_metadata_request_record()

    #expect(unsafe record.call_count == expectedCallCount)
    #expect(unsafe record.kind == expectedKind)
    if let expectedObject {
        #expect(unsafe record.object == UnsafeMutableRawPointer(bitPattern: expectedObject))
    }
    if let expectedSurface {
        #expect(unsafe record.surface == UnsafeMutableRawPointer(bitPattern: expectedSurface))
    }
    if let expectedReference {
        #expect(
            unsafe record.reference == UnsafeMutableRawPointer(bitPattern: expectedReference)
        )
    }
    if let expectedImageDescription {
        #expect(
            unsafe record.image_description
                == UnsafeMutableRawPointer(bitPattern: expectedImageDescription)
        )
    }
    if let expectedValue {
        #expect(unsafe record.value == expectedValue)
    }
    if let expectedCoefficients {
        #expect(unsafe record.coefficients == expectedCoefficients)
    }
    if let expectedRange {
        #expect(unsafe record.range == expectedRange)
    }
    if let expectedRenderIntent {
        #expect(unsafe record.render_intent == expectedRenderIntent)
    }
}

func expectMetadataRequestCallCount(_ expectedCallCount: Int32) {
    #expect(unsafe swl_test_metadata_request_record().call_count == expectedCallCount)
}

func expectMetadataListener(object expectedObject: UInt) {
    let listenerRecord = unsafe swl_test_metadata_listener_record()

    #expect(unsafe listenerRecord.call_count == 1)
    #expect(unsafe listenerRecord.object == UnsafeMutableRawPointer(bitPattern: expectedObject))
}

func testSurface(pointer rawPointer: UInt) throws -> RawSurface {
    try unsafe RawSurface.testingSurface(
        pointer: testPointer(rawPointer),
        version: 6,
        proxyAdoption: try testAdoptionContext()
    )
}

func testAdoptionContext() throws -> RawProxyAdoptionContext {
    let eventQueue = unsafe RawEventQueue.testingQueueWithoutDestroy(
        opaquePointer: try testPointer(0xC999)
    )
    return RawProxyAdoptionContext(eventQueue: eventQueue)
}

func testImageDescriptionReference(pointer rawPointer: UInt) throws
    -> RawImageDescriptionReference
{
    try unsafe RawImageDescriptionReference(
        pointer: testPointer(rawPointer),
        destroy: ignoreTestMetadataDestroy
    )
}

func testPointer(_ rawPointer: UInt) throws -> OpaquePointer {
    try unsafe #require(OpaquePointer(bitPattern: rawPointer))
}

func ignoreTestMetadataDestroy(_: OpaquePointer) {
    // Test-owned fake proxies do not need protocol destruction.
}
