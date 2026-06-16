#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @testable import WaylandRaw

    private let testConfigurationPointer: UInt = 0xC810
    private let testConfigurationHeadPointer: UInt = 0xC811

    private struct OutputRequestPointerFields {
        var object: UInt?
        var configuration: UInt?
        var configurationHead: UInt?
        var head: UInt?
        var mode: UInt?
    }

    private struct OutputRequestScalarFields {
        var serial: UInt32?
        var x: Int32?
        var y: Int32?
        var width: Int32?
        var height: Int32?
        var refresh: Int32?
        var transform: Int32?
        var scale: Int32?
    }

    @Suite(.serialized)
    struct RawOutputManagementRequestTests {
        @Test
        func outputManagerDestroySendsStopWithoutLocalDestroy() async throws {
            let pointer = try unsafe #require(OpaquePointer(bitPattern: 0xC700))

            try await withOutputRequestRecording {
                let manager = RawWlrOutputManager.testingOutputManager(
                    pointer: pointer,
                    version: RawVersion(4),
                    proxyAdoption: try outputTestAdoptionContext()
                )

                manager.destroy()
                manager.destroy()

                #expect(throws: RuntimeError.invalidArgument("zwlr_output_manager_v1 stopped")) {
                    try manager.createConfiguration(serial: 1)
                }
                assertReleaseRecord(
                    expectedKind: SWL_TEST_OUTPUT_MANAGER_STOP,
                    pointer: pointer
                )
            }
        }

        @Test
        func outputManagerCreateConfigurationPreservesSerial() async throws {
            try await withOutputRequestRecording {
                try assertManagerCreateConfigurationRequest()
            }
        }

        @Test
        func outputConfigurationEnableDisableTestApplyAndDestroyRequests()
            async throws
        {
            try await withOutputRequestRecording {
                try assertConfigurationLifecycleRequests()
            }
        }

        @Test
        func outputConfigurationRetainsEnabledHeadUntilDestroy()
            async throws
        {
            try await withOutputRequestRecording {
                try assertConfigurationRetainsEnabledHeadUntilDestroy()
            }
        }

        @Test
        func outputConfigurationHeadRequestsPreserveModeAndLayout()
            async throws
        {
            try await withOutputRequestRecording {
                try assertConfigurationHeadLayoutRequests()
            }
        }

        @Test
        func outputHeadAndModeDestroySendReleaseRequests() async throws {
            try await assertHeadReleaseRequest(
                pointer: 0xC701,
                version: RawVersion(3),
                expectedKind: SWL_TEST_OUTPUT_HEAD_RELEASE
            )
            try await assertModeReleaseRequest(
                pointer: 0xC702,
                version: RawVersion(3),
                expectedKind: SWL_TEST_OUTPUT_MODE_RELEASE
            )
        }

        @Test
        func outputHeadAndModeBeforeVersion3UseLocalDestroy() async throws {
            try await assertHeadReleaseRequest(
                pointer: 0xC703,
                version: RawVersion(2),
                expectedKind: SWL_TEST_OUTPUT_HEAD_DESTROY
            )
            try await assertModeReleaseRequest(
                pointer: 0xC704,
                version: RawVersion(2),
                expectedKind: SWL_TEST_OUTPUT_MODE_DESTROY
            )
        }
    }

    private func assertManagerCreateConfigurationRequest() throws {
        let manager = try unsafe RawWlrOutputManager.testingOutputManager(
            pointer: outputTestPointer(0xC720),
            version: RawVersion(4),
            proxyAdoption: outputTestAdoptionContext()
        )
        defer { manager.destroy() }

        let configuration = try manager.createConfiguration(serial: 77)
        defer { configuration.destroy() }

        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_MANAGER_CREATE_CONFIGURATION,
            callCount: 1,
            object: 0xC720,
            configuration: testConfigurationPointer,
            serial: 77
        )
    }

    private func assertConfigurationLifecycleRequests() throws {
        let configuration = try unsafe RawWlrOutputConfiguration(
            pointer: outputTestPointer(testConfigurationPointer)
        )
        let head = try unsafe RawWlrOutputHead(
            pointer: outputTestPointer(0xC731),
            version: RawVersion(4)
        )
        defer { head.abandonAfterManagerFinished() }

        let configurationHead = try configuration.enable(head: head)
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_ENABLE_HEAD,
            callCount: 1,
            object: testConfigurationPointer,
            configuration: testConfigurationPointer,
            configurationHead: testConfigurationHeadPointer,
            head: 0xC731
        )

        configuration.disable(head: head)
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_DISABLE_HEAD,
            callCount: 2,
            object: testConfigurationPointer,
            configuration: testConfigurationPointer,
            head: 0xC731
        )

        configuration.test()
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_TEST,
            callCount: 3,
            object: testConfigurationPointer,
            configuration: testConfigurationPointer
        )

        configuration.apply()
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_APPLY,
            callCount: 4,
            object: testConfigurationPointer,
            configuration: testConfigurationPointer
        )

        configurationHead.destroy()
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_HEAD_DESTROY,
            callCount: 5,
            object: testConfigurationHeadPointer,
            configurationHead: testConfigurationHeadPointer
        )

        configuration.destroy()
        configuration.destroy()
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_DESTROY,
            callCount: 6,
            object: testConfigurationPointer,
            configuration: testConfigurationPointer
        )
    }

    private func assertConfigurationRetainsEnabledHeadUntilDestroy() throws {
        let configuration = try unsafe RawWlrOutputConfiguration(
            pointer: outputTestPointer(testConfigurationPointer)
        )
        let head = try unsafe RawWlrOutputHead(
            pointer: outputTestPointer(0xC735),
            version: RawVersion(4)
        )
        defer { head.abandonAfterManagerFinished() }

        do {
            _ = try configuration.enable(head: head)
        }
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_ENABLE_HEAD,
            callCount: 1,
            object: testConfigurationPointer,
            configuration: testConfigurationPointer,
            configurationHead: testConfigurationHeadPointer,
            head: 0xC735
        )

        configuration.test()
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_TEST,
            callCount: 2,
            object: testConfigurationPointer,
            configuration: testConfigurationPointer
        )

        configuration.destroy()
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_DESTROY,
            callCount: 3,
            object: testConfigurationPointer,
            configuration: testConfigurationPointer
        )
    }

    private func assertConfigurationHeadLayoutRequests() throws {
        let configurationHead = try unsafe RawWlrOutputConfigurationHead(
            pointer: outputTestPointer(testConfigurationHeadPointer)
        )
        let mode = try unsafe RawWlrOutputMode(
            pointer: outputTestPointer(0xC741),
            version: RawVersion(4)
        )
        defer { mode.abandonAfterManagerFinished() }

        configurationHead.setMode(mode)
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_HEAD_SET_MODE,
            callCount: 1,
            object: testConfigurationHeadPointer,
            configurationHead: testConfigurationHeadPointer,
            mode: 0xC741
        )

        configurationHead.setCustomMode(width: 1_024, height: 768, refresh: 60_000)
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_HEAD_SET_CUSTOM_MODE,
            callCount: 2,
            object: testConfigurationHeadPointer,
            configurationHead: testConfigurationHeadPointer,
            width: 1_024,
            height: 768,
            refresh: 60_000
        )

        configurationHead.setPosition(x: -10, y: 20)
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_HEAD_SET_POSITION,
            callCount: 3,
            object: testConfigurationHeadPointer,
            configurationHead: testConfigurationHeadPointer,
            x: -10,
            y: 20
        )

        configurationHead.setTransform(5)
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_HEAD_SET_TRANSFORM,
            callCount: 4,
            object: testConfigurationHeadPointer,
            configurationHead: testConfigurationHeadPointer,
            transform: 5
        )

        configurationHead.setScale(WaylandFixed(rawValue: 512))
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_HEAD_SET_SCALE,
            callCount: 5,
            object: testConfigurationHeadPointer,
            configurationHead: testConfigurationHeadPointer,
            scale: 512
        )

        configurationHead.destroy()
        assertOutputRequest(
            expectedKind: SWL_TEST_OUTPUT_CONFIGURATION_HEAD_DESTROY,
            callCount: 6,
            object: testConfigurationHeadPointer,
            configurationHead: testConfigurationHeadPointer
        )
    }

    private func assertHeadReleaseRequest(
        pointer rawPointer: UInt,
        version: RawVersion,
        expectedKind: swl_test_output_destroy_kind,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))

        try await withOutputRequestRecording {
            RawWlrOutputHead(pointer: pointer, version: version).destroy()

            assertReleaseRecord(
                expectedKind: expectedKind,
                pointer: pointer,
                sourceLocation: sourceLocation
            )
        }
    }

    private func assertModeReleaseRequest(
        pointer rawPointer: UInt,
        version: RawVersion,
        expectedKind: swl_test_output_destroy_kind,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))

        try await withOutputRequestRecording {
            RawWlrOutputMode(pointer: pointer, version: version).destroy()

            assertReleaseRecord(
                expectedKind: expectedKind,
                pointer: pointer,
                sourceLocation: sourceLocation
            )
        }
    }

    private func withOutputRequestRecording(_ operation: () throws -> Void) async throws {
        try await CoreRequestRecordingGate.withExclusiveRecording {
            swl_test_core_request_recording_begin()
            swl_test_output_request_recording_begin()
            defer { swl_test_output_request_recording_end() }
            defer { swl_test_core_request_recording_end() }
            try operation()
        }
    }

    private func outputTestAdoptionContext() throws -> RawProxyAdoptionContext {
        let eventQueue = RawEventQueue.testingQueueWithoutDestroy(
            opaquePointer: try unsafe #require(OpaquePointer(bitPattern: 0xC799))
        )
        return RawProxyAdoptionContext(eventQueue: eventQueue)
    }

    private func outputTestPointer(_ rawPointer: UInt) throws -> OpaquePointer {
        try unsafe #require(OpaquePointer(bitPattern: rawPointer))
    }

    @safe
    private func assertOutputRequest(
        expectedKind: swl_test_output_request_kind,
        callCount expectedCallCount: Int32,
        object expectedObject: UInt? = nil,
        configuration expectedConfiguration: UInt? = nil,
        configurationHead expectedConfigurationHead: UInt? = nil,
        head expectedHead: UInt? = nil,
        mode expectedMode: UInt? = nil,
        serial expectedSerial: UInt32? = nil,
        x expectedX: Int32? = nil,
        y expectedY: Int32? = nil,
        width expectedWidth: Int32? = nil,
        height expectedHeight: Int32? = nil,
        refresh expectedRefresh: Int32? = nil,
        transform expectedTransform: Int32? = nil,
        scale expectedScale: Int32? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let record = unsafe swl_test_output_request_record()
        #expect(unsafe record.call_count == expectedCallCount, sourceLocation: sourceLocation)
        #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
        let pointerFields = OutputRequestPointerFields(
            object: expectedObject,
            configuration: expectedConfiguration,
            configurationHead: expectedConfigurationHead,
            head: expectedHead,
            mode: expectedMode
        )
        let scalarFields = OutputRequestScalarFields(
            serial: expectedSerial,
            x: expectedX,
            y: expectedY,
            width: expectedWidth,
            height: expectedHeight,
            refresh: expectedRefresh,
            transform: expectedTransform,
            scale: expectedScale
        )
        assertOutputRequestPointers(
            record,
            expected: pointerFields,
            sourceLocation: sourceLocation
        )
        assertOutputRequestScalars(
            record,
            expected: scalarFields,
            sourceLocation: sourceLocation
        )
    }

    @safe
    private func assertOutputRequestPointers(
        _ record: swl_test_output_request_record,
        expected: OutputRequestPointerFields,
        sourceLocation: SourceLocation
    ) {
        unsafe expectPointer(record.object, equals: expected.object, sourceLocation: sourceLocation)
        expectPointer(
            unsafe record.configuration,
            equals: expected.configuration,
            sourceLocation: sourceLocation
        )
        expectPointer(
            unsafe record.configuration_head,
            equals: expected.configurationHead,
            sourceLocation: sourceLocation
        )
        unsafe expectPointer(record.head, equals: expected.head, sourceLocation: sourceLocation)
        unsafe expectPointer(record.mode, equals: expected.mode, sourceLocation: sourceLocation)
    }

    @safe
    private func assertOutputRequestScalars(
        _ record: swl_test_output_request_record,
        expected: OutputRequestScalarFields,
        sourceLocation: SourceLocation
    ) {
        if let serial = expected.serial {
            #expect(unsafe record.serial == serial, sourceLocation: sourceLocation)
        }
        unsafe expectInt32(record.x, equals: expected.x, sourceLocation: sourceLocation)
        unsafe expectInt32(record.y, equals: expected.y, sourceLocation: sourceLocation)
        unsafe expectInt32(record.width, equals: expected.width, sourceLocation: sourceLocation)
        unsafe expectInt32(record.height, equals: expected.height, sourceLocation: sourceLocation)
        unsafe expectInt32(record.refresh, equals: expected.refresh, sourceLocation: sourceLocation)
        unsafe expectInt32(
            record.transform,
            equals: expected.transform,
            sourceLocation: sourceLocation
        )
        unsafe expectInt32(record.scale, equals: expected.scale, sourceLocation: sourceLocation)
    }

    @safe
    private func expectPointer(
        _ actual: UnsafeMutableRawPointer?,
        equals expected: UInt?,
        sourceLocation: SourceLocation
    ) {
        guard let expected else { return }

        #expect(
            unsafe actual == UnsafeMutableRawPointer(bitPattern: expected),
            sourceLocation: sourceLocation
        )
    }

    @safe
    private func expectInt32(
        _ actual: Int32,
        equals expected: Int32?,
        sourceLocation: SourceLocation
    ) {
        guard let expected else { return }

        #expect(actual == expected, sourceLocation: sourceLocation)
    }

    @safe
    private func assertReleaseRecord(
        expectedKind: swl_test_output_destroy_kind,
        pointer: OpaquePointer,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let record = unsafe swl_test_output_destroy_record()
        #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
        #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
        #expect(
            unsafe record.object == UnsafeMutableRawPointer(pointer),
            sourceLocation: sourceLocation
        )
    }
#endif
