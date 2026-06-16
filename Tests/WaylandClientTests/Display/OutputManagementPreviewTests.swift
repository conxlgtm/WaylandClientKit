import Testing

@testable import WaylandClient
@testable import WaylandRaw

#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import WaylandTestSupport
#endif

@Suite
struct OutputManagementPreviewTests {
    @Test
    func collectorBuildsSnapshotFromDoneBoundFacts() throws {
        var nextHeadID: UInt64 = 1
        var nextModeID: UInt64 = 10
        let collector = OutputManagementCollector(
            headIDProvider: { _ in
                defer { nextHeadID += 1 }
                return OutputManagementHeadID(rawValue: nextHeadID)
            },
            modeIDProvider: {
                defer { nextModeID += 1 }
                return OutputManagementModeID(rawValue: nextModeID)
            }
        )
        let head = RawWlrOutputHead(pointer: try unsafe fakePointer(0xA01), version: RawVersion(4))
        let mode = RawWlrOutputMode(pointer: try unsafe fakePointer(0xA02), version: RawVersion(4))
        defer {
            head.abandonAfterManagerFinished()
            mode.abandonAfterManagerFinished()
        }

        collector.handle(.head(head))
        collector.handle(.headEvent(head, .name("DP-1")))
        collector.handle(.headEvent(head, .description("Example display")))
        collector.handle(.headEvent(head, .enabled(true)))
        collector.handle(.headEvent(head, .position(x: 10, y: 20)))
        collector.handle(.headEvent(head, .transform(OutputTransform.rotated90.rawValue)))
        collector.handle(.headEvent(head, .scale(WaylandFixed(rawValue: 384))))
        collector.handle(.headEvent(head, .make("Example")))
        collector.handle(.headEvent(head, .model("Panel")))
        collector.handle(.headEvent(head, .serialNumber("ABC123")))
        collector.handle(.headEvent(head, .mode(mode)))
        collector.handle(.modeEvent(head, mode, .size(width: 1_920, height: 1_080)))
        collector.handle(.modeEvent(head, mode, .refresh(60_000)))
        collector.handle(.modeEvent(head, mode, .preferred))
        collector.handle(.headEvent(head, .currentMode(mode)))
        collector.handle(.done(42))

        let snapshot = try collector.snapshot()

        #expect(snapshot.serial == 42)
        #expect(snapshot.heads.count == 1)
        let outputHead = try #require(snapshot.heads.first)
        #expect(outputHead.id == OutputManagementHeadID(rawValue: 1))
        #expect(outputHead.name == "DP-1")
        #expect(outputHead.description == "Example display")
        #expect(outputHead.enabled)
        #expect(outputHead.position == LogicalOffset(x: 10, y: 20))
        #expect(outputHead.transform == .rotated90)
        #expect(outputHead.scale == (try SurfaceScale(numerator: 384, denominator: 256)))
        #expect(outputHead.make == "Example")
        #expect(outputHead.model == "Panel")
        #expect(outputHead.serialNumber == "ABC123")
        #expect(outputHead.modes.count == 1)

        let outputMode = try #require(outputHead.modes.first)
        #expect(outputMode.id == OutputManagementModeID(rawValue: 10))
        #expect(outputMode.size == (try PositivePixelSize(width: 1_920, height: 1_080)))
        #expect(
            outputMode.refresh == OutputRefreshRate.milliHertz(PositiveInt32(unchecked: 60_000)))
        #expect(outputMode.isPreferred)
        #expect(outputMode.isCurrent)
    }

    @Test
    func collectorRejectsMissingDoneSerial() throws {
        let collector = OutputManagementCollector(
            headIDProvider: { _ in OutputManagementHeadID(rawValue: 1) },
            modeIDProvider: { OutputManagementModeID(rawValue: 1) }
        )

        #expect(throws: ClientError.display(.outputManagementIncomplete)) {
            _ = try collector.snapshot()
        }
    }

    @Test
    func collectorIgnoresLateEventsAfterManagerFinished() throws {
        let collector = OutputManagementCollector(
            headIDProvider: { _ in OutputManagementHeadID(rawValue: 1) },
            modeIDProvider: { OutputManagementModeID(rawValue: 1) }
        )
        let lateHead = RawWlrOutputHead(
            pointer: try unsafe fakePointer(0xA09),
            version: RawVersion(4)
        )
        defer { lateHead.abandonAfterManagerFinished() }

        collector.handle(.done(9))
        collector.handle(.finished)
        collector.handle(.head(lateHead))
        collector.handle(.headEvent(lateHead, .name("late")))

        let snapshot = try collector.snapshot()
        #expect(snapshot.serial == 9)
        #expect(snapshot.heads.isEmpty)
    }

    @Test
    func collectorRemovesFinishedHeadsAndModes() throws {
        let collector = OutputManagementCollector(
            headIDProvider: { _ in OutputManagementHeadID(rawValue: 1) },
            modeIDProvider: { OutputManagementModeID(rawValue: 1) }
        )
        let head = RawWlrOutputHead(pointer: try unsafe fakePointer(0xA11), version: RawVersion(4))
        let mode = RawWlrOutputMode(pointer: try unsafe fakePointer(0xA12), version: RawVersion(4))
        defer {
            head.abandonAfterManagerFinished()
            mode.abandonAfterManagerFinished()
        }

        collector.handle(.head(head))
        collector.handle(.headEvent(head, .mode(mode)))
        collector.handle(.modeEvent(head, mode, .size(width: 800, height: 600)))
        collector.handle(.modeEvent(head, mode, .finished))
        collector.handle(.done(5))

        var snapshot = try collector.snapshot()
        #expect(snapshot.heads.first?.modes.isEmpty == true)

        collector.handle(.headEvent(head, .finished))
        snapshot = try collector.snapshot()
        #expect(snapshot.heads.isEmpty)
    }

    @Test
    func staleConfigurationProposalIsRejectedBeforeRequests() throws {
        let firstSnapshot = OutputManagementSnapshot(heads: [], serial: 11)
        let secondSnapshot = OutputManagementSnapshot(heads: [], serial: 12)
        let proposal = OutputConfigurationProposal(current: firstSnapshot)

        #expect(throws: ClientError.display(.staleOutputConfiguration)) {
            try DisplayCore.validateOutputConfigurationProposal(
                proposal,
                against: secondSnapshot
            )
        }
    }

    #if SWL_ENABLE_TESTING
        @Test
        func currentStateConfigurationMapsEnabledHeadRequests() async throws {
            try await withOutputRequestRecording {
                try assertCurrentStateConfigurationMapsEnabledHeadRequests()
            }
        }

        @Test
        func currentStateConfigurationMapsDisabledHeadRequest() async throws {
            try await withOutputRequestRecording {
                let collector = OutputManagementCollector(
                    headIDProvider: { _ in OutputManagementHeadID(rawValue: 1) },
                    modeIDProvider: { OutputManagementModeID(rawValue: 1) }
                )
                let head = RawWlrOutputHead(
                    pointer: try unsafe fakePointer(0xA41),
                    version: RawVersion(4)
                )
                let manager = RawWlrOutputManager.testingOutputManager(
                    pointer: try unsafe fakePointer(0xA42),
                    version: RawVersion(4),
                    proxyAdoption: try testAdoptionContext()
                )
                defer {
                    head.abandonAfterManagerFinished()
                    manager.destroy()
                }

                collector.handle(.head(head))
                collector.handle(.headEvent(head, .enabled(false)))
                collector.handle(.done(14))

                let collection = try collector.collection(manager: manager)
                let configuration = try RawWlrOutputConfiguration(
                    pointer: try unsafe fakePointer(0xA43)
                )
                try collection.configureCurrentState(on: configuration)

                let record = unsafe swl_test_output_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_OUTPUT_CONFIGURATION_DISABLE_HEAD)
                #expect(unsafe record.head == UnsafeMutableRawPointer(head.pointer))
            }
        }
    #endif

    @Test
    func configurationResultMappingIsTyped() {
        #expect(DisplayCore.outputManagementConfigurationError(for: .succeeded) == nil)
        #expect(
            DisplayCore.outputManagementConfigurationError(for: .failed)
                == ClientError.display(.outputConfigurationFailed)
        )
        #expect(
            DisplayCore.outputManagementConfigurationError(for: .cancelled)
                == ClientError.display(.outputConfigurationCancelled)
        )
        #expect(
            DisplayCore.outputManagementConfigurationError(for: nil)
                == ClientError.display(.outputConfigurationFailed)
        )
    }
}

#if SWL_ENABLE_TESTING
    private func assertCurrentStateConfigurationMapsEnabledHeadRequests() throws {
        let collector = OutputManagementCollector(
            headIDProvider: { _ in OutputManagementHeadID(rawValue: 1) },
            modeIDProvider: { OutputManagementModeID(rawValue: 1) }
        )
        let head = RawWlrOutputHead(
            pointer: try unsafe fakePointer(0xA31),
            version: RawVersion(4)
        )
        let mode = RawWlrOutputMode(
            pointer: try unsafe fakePointer(0xA32),
            version: RawVersion(4)
        )
        let manager = RawWlrOutputManager.testingOutputManager(
            pointer: try unsafe fakePointer(0xA33),
            version: RawVersion(4),
            proxyAdoption: try testAdoptionContext()
        )
        defer {
            head.abandonAfterManagerFinished()
            mode.abandonAfterManagerFinished()
            manager.destroy()
        }

        collector.handle(.head(head))
        collector.handle(.headEvent(head, .enabled(true)))
        collector.handle(.headEvent(head, .mode(mode)))
        collector.handle(.headEvent(head, .currentMode(mode)))
        collector.handle(.headEvent(head, .position(x: 50, y: -25)))
        collector.handle(.headEvent(head, .transform(2)))
        collector.handle(.headEvent(head, .scale(WaylandFixed(rawValue: 512))))
        collector.handle(.done(13))

        let collection = try collector.collection(manager: manager)
        let configuration = try RawWlrOutputConfiguration(
            pointer: try unsafe fakePointer(0xA34)
        )
        try collection.configureCurrentState(on: configuration)

        let record = unsafe swl_test_output_request_record()
        #expect(unsafe record.call_count == 6)
        #expect(unsafe record.kind == SWL_TEST_OUTPUT_CONFIGURATION_HEAD_DESTROY)
        #expect(unsafe record.configuration_head != nil)
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

    private func testAdoptionContext() throws -> RawProxyAdoptionContext {
        RawProxyAdoptionContext(
            eventQueue: RawEventQueue.testingQueueWithoutDestroy(
                opaquePointer: try unsafe fakePointer(0xA99)
            )
        )
    }
#endif

private enum FakePointerError: Error {
    case invalid(UInt)
}

private func fakePointer(_ bitPattern: UInt) throws -> OpaquePointer {
    guard let pointer = unsafe OpaquePointer(bitPattern: bitPattern) else {
        throw FakePointerError.invalid(bitPattern)
    }
    return unsafe pointer
}
